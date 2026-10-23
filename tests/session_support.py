import json
import os
from pathlib import Path
import subprocess
import time
from array import array

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'lab/game'
processes = []
run_id = str(time.time_ns())
roles = ['host', 'guest1', 'guest2', 'guest3']

def user_dir(role):
    return ROOT / 'local/profiles' / run_id / role / 'Godot/app_userdata/Haystack Incremental'

def launch(role):
    env = os.environ.copy()
    env.update(APPDATA=str(ROOT / 'local/profiles' / run_id / role), NEEDLENET_TEST='1', NEEDLENET_ROLE=role)
    p = subprocess.Popen([str(GAME / 'FindTheNeedle.exe'), '--headless', '--path', str(GAME), '--script', str(ROOT / 'tests/session_test.gd'), '--log-file', str(ROOT / f'local/{role}.log')], env=env, cwd=GAME, creationflags=subprocess.CREATE_NO_WINDOW)
    processes.append(p)
    print(f'{role} pid={p.pid}', flush=True)

def states():
    result = []
    for role in roles:
        try:
            result.append(json.loads((user_dir(role) / 'nn_state.json').read_text(encoding='utf-8')))
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

def command(role, action, **kwargs):
    (user_dir(role) / 'nn_command.json').write_text(json.dumps({'action': action, 'id': time.time_ns(), **kwargs}))

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

