from session_support import *

def prop_on_all(ss, ident, predicate):
    return ready(ss) and all(str(ident) in s.get('props', {}) and s['props'][str(ident)]['strands'] == 1000 and predicate(s['props'][str(ident)]) for s in ss)

def spawn(kind):
    command('host', 'spawn_fixture', kind=kind)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        try:
            fixture = json.loads((user_dir('host') / 'nn_fixture.json').read_text())
            if fixture['kind'] == kind and fixture['id']:
                return fixture['id']
        except (OSError, ValueError):
            pass
        time.sleep(0.2)
    raise RuntimeError(f'Failed to spawn {kind}')

try:
    for role in roles:
        launch(role)
        time.sleep(3 if role == 'host' else 1)
    initial = wait_for(ready)
    print('CATALOG', initial[0]['item_catalog'], flush=True)
    ident = spawn('hay_wad')
    wait_for(lambda ss: prop_on_all(ss, ident, lambda p: p['owner'] == 'host' and not p['held']), 30)
    command('guest1', 'carry_fixture', prop=ident)
    wait_for(lambda ss: prop_on_all(ss, ident, lambda p: p['owner'] == 'guest1' and p['held']) and next(s for s in ss if s['role'] == 'guest1')['carrying'], 30)
    print('GUEST_HAY_CARRY_PASS', flush=True)
    old_x = next(s for s in states() if s['role'] == 'host')['props'][str(ident)]['x']
    command('guest1', 'move')
    wait_for(lambda ss: prop_on_all(ss, ident, lambda p: p['owner'] == 'guest1' and p['held'] and abs(p['x'] - old_x - 2) < 0.3), 30)
    print('HELD_HAY_MOVEMENT_PASS', flush=True)
    command('guest1', 'drop_cargo')
    wait_for(lambda ss: prop_on_all(ss, ident, lambda p: not p['held']), 30)
    print('HAY_DROP_PASS', flush=True)
    command('guest2', 'carry_fixture', prop=ident)
    command('guest3', 'carry_fixture', prop=ident)
    contenders = wait_for(lambda ss: prop_on_all(ss, ident, lambda p: p['held'] and p['owner'] in ['guest2', 'guest3']) and len({s['props'][str(ident)]['owner'] for s in ss}) == 1 and sum(s['carrying'] for s in ss) == 1, 30)
    winner = contenders[0]['props'][str(ident)]['owner']
    print('COMPETING_CLAIM_PASS', winner, flush=True)
    command(winner, 'leave')
    wait_for(lambda ss: next(s for s in ss if s['role'] == 'host')['players'] == 3 and all(str(ident) in s.get('props', {}) and s['props'][str(ident)]['owner'] == 'host' and not s['props'][str(ident)]['held'] for s in ss if s['role'] != winner), 30)
    print('DISCONNECT_CARGO_RECOVERY_PASS', flush=True)
    command(winner, 'rejoin')
    wait_for(lambda ss: prop_on_all(ss, ident, lambda p: p['owner'] == 'host' and not p['held']), 90)
    print('REJOIN_CARGO_PASS', flush=True)
    catalog = initial[0]['item_catalog']
    checked_kinds = ['hay_wad']
    for kind in ['paper', 'paper_roll', 'paper_sheet', 'hay_bale', 'bale', 'briquette', 'pellet']:
        if not catalog.get(kind):
            continue
        fixture = spawn(kind)
        wait_for(lambda ss: prop_on_all(ss, fixture, lambda p: p['owner'] == 'host'), 30)
        command('guest1', 'carry_fixture', prop=fixture)
        wait_for(lambda ss: prop_on_all(ss, fixture, lambda p: p['owner'] == 'guest1' and p['held']), 30)
        command('guest1', 'drop_cargo')
        wait_for(lambda ss: prop_on_all(ss, fixture, lambda p: not p['held']), 30)
        print('ITEM_CARRY_PASS', kind, flush=True)
        checked_kinds.append(kind)
    name = 'items-chaos-result.json' if os.environ.get('NEEDLENET_CONNECT_PORT') else 'items-result.json'
    (ROOT / 'local' / name).write_text(json.dumps({'checks': ['hay_carry', 'held_movement', 'drop', 'competing_claim', 'disconnect_recovery', 'rejoin_cargo'], 'item_kinds': checked_kinds, 'states': states()}, indent=2))
finally:
    for p in processes:
        if p.poll() is None:
            p.terminate()
    for p in processes:
        p.wait(timeout=15)
