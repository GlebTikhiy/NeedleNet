import json
import os
from pathlib import Path
import subprocess
import time
from array import array

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / 'lab/game'
processes = []
run_id = str(time.time_ns())
roles = ['host', 'guest1', 'guest2', 'guest3']

def user_dir(role):
    return ROOT / 'local/profiles' / run_id / role / 'Godot/app_userdata/Haystack Incremental'

def launch(role):
    env = os.environ.copy()
    env.update(APPDATA=str(ROOT / 'local/profiles' / run_id / role), NEEDLENET_TEST='1', NEEDLENET_ROLE=role)
    p = subprocess.Popen([str(GAME / 'FindTheNeedle.exe'), '--headless', '--path', str(GAME), '--script', str(ROOT / 'dev/tests/session_test.gd'), '--log-file', str(ROOT / f'local/{role}.log')], env=env, cwd=GAME, creationflags=subprocess.CREATE_NO_WINDOW)
    processes.append(p)
    print(f'{role} pid={p.pid}', flush=True)

def states():
    result = []
    for role in roles:
        try:
            result.append(json.loads((user_dir(role) / 'nn_state.json').read_text()))
        except (OSError, ValueError):
            pass
    return result

def wait_for(predicate, timeout=150):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if any(p.poll() is not None for p in processes):
            raise RuntimeError('A game process exited unexpectedly')
        current = states()
        if len(current) == 4 and predicate(current):
            return current
        time.sleep(1)
    raise RuntimeError(f'Timed out, states={states()}')

def command(role, action):
    (user_dir(role) / 'nn_command.json').write_text(json.dumps({'action': action, 'id': time.time_ns()}))

def ready(ss):
    return all(s.get('world') and s.get('players') == 4 and s.get('avatars') == 3 for s in ss) and len({s['seed'] for s in ss}) == 1

def hay_values(role):
    values = array('f')
    values.frombytes((user_dir(role) / 'nn_heights.bin').read_bytes())
    return values

def hay_consistent(ss):
    if not ready(ss):
        return False
    try:
        host = hay_values('host')
        for role in roles[1:]:
            guest = hay_values(role)
            if len(guest) != len(host) or max(abs(a - b) for a, b in zip(host, guest)) > 0.0021:
                return False
        return True
    except (OSError, ValueError):
        return False

try:
    for role in roles:
        launch(role)
        time.sleep(3 if role == 'host' else 1)
    initial = wait_for(ready)
    print('FOUR_CLIENT_WORLD_PASS', flush=True)
    initial = wait_for(hay_consistent, 40)
    old_hay = initial[0]['hay_hash']
    old_sum = initial[0]['hay_sum']
    command('guest2', 'dig')
    wait_for(lambda ss: hay_consistent(ss) and ss[0]['hay_hash'] != old_hay and ss[0]['hay_sum'] < old_sum - 0.1, 60)
    print('GUEST_HAY_FULL_CONTENT_PASS', flush=True)
    baseline = initial[0]['money']
    command('guest1', 'money')
    wait_for(lambda ss: ready(ss) and all(abs(s['money'] - baseline - 17) < 0.01 for s in ss), 30)
    print('SHARED_MONEY_PASS', flush=True)
    before = next(s for s in states() if s['role'] == 'host')['pose_x']['guest1']
    command('guest1', 'move')
    wait_for(lambda ss: ready(ss) and abs(next(s for s in ss if s['role'] == 'host')['pose_x'].get('guest1', before) - before - 2) < 0.1, 30)
    print('REMOTE_MOVEMENT_PASS', flush=True)
    command('host', 'drop_tool')
    wait_for(lambda ss: ready(ss) and all(s['loose_brooms'] == 1 for s in ss) and not next(s for s in ss if s['role'] == 'host')['broom_owned'], 30)
    command('guest1', 'pickup_tool')
    wait_for(lambda ss: ready(ss) and all(s['loose_brooms'] == 0 for s in ss) and next(s for s in ss if s['role'] == 'guest1')['broom_owned'], 30)
    command('guest1', 'repeat_pickup')
    time.sleep(7)
    ss = states()
    if not (ready(ss) and all(s['loose_brooms'] == 0 and abs(s['money'] - baseline - 17) < 0.01 for s in ss) and sum(s['broom_owned'] for s in ss) == 1):
        raise RuntimeError('Tool pickup duplicated an item or changed money')
    print('HOST_DROP_GUEST_PICKUP_NO_DUPLICATION_PASS', flush=True)
    launch('overflow')
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        try:
            overflow = json.loads((user_dir('overflow') / 'nn_state.json').read_text())
            if overflow['players'] or overflow['world']:
                raise RuntimeError(f'Fifth player admitted: {overflow}')
            if overflow['phase'] == 0:
                break
        except (OSError, ValueError):
            pass
        time.sleep(1)
    else:
        raise RuntimeError('Fifth connection never stopped connecting')
    print('FIFTH_PLAYER_REJECTED_PASS', flush=True)
    command('guest3', 'leave')
    wait_for(lambda ss: next(s for s in ss if s['role'] == 'host')['players'] == 3, 30)
    print('DISCONNECT_PASS', flush=True)
    command('guest3', 'rejoin')
    final = wait_for(lambda ss: ready(ss) and all(abs(s['money'] - baseline - 17) < 0.01 for s in ss), 90)
    print('REJOIN_WORLD_PASS', flush=True)
    command('host', 'save')
    saved = wait_for(lambda ss: ready(ss) and next(s for s in ss if s['role'] == 'host').get('saved'), 30)
    expected_hay = hay_values('host')
    command('host', 'menu')
    wait_for(lambda ss: all(not s['world'] for s in ss), 30)
    command('host', 'reload')
    final = wait_for(lambda ss: hay_consistent(ss) and all(abs(s['money'] - baseline - 17) < 0.01 for s in ss) and max(abs(a-b) for a,b in zip(hay_values('host'), expected_hay)) <= 0.0021, 120)
    print('HOST_SAVE_RELOAD_PASS', flush=True)
    (ROOT / 'local/session_result-v2.json').write_text(json.dumps({'checks': ['four_clients', 'world_seed', 'remote_avatars', 'guest_hay_full_content', 'shared_money', 'remote_movement', 'host_drop_guest_pickup_no_duplication', 'fifth_timeout', 'disconnect', 'rejoin', 'host_save_reload'], 'states': final}, indent=2))
finally:
    for p in processes:
        if p.poll() is None:
            p.terminate()
    for p in processes:
        p.wait(timeout=15)
