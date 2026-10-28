"""Four isolated real game processes: native factory load and host crash recovery.

Never uses the player's APPDATA. Outputs private evidence under local/.
Headless timings measure simulation, not rendered frame rate.
"""
from session_support import *
import hashlib
import psutil
import statistics
import sys
import traceback

os.environ['NEEDLENET_COMPACT'] = '1'
OUT = ROOT / 'local' / f'release-candidate-{run_id}'
OUT.mkdir(parents=True)
checks, samples = [], []
BELTS = int(os.environ.get('NN_STRESS_BELTS', '128'))
CARGO = int(os.environ.get('NN_STRESS_CARGO', '1024'))
DURATION = int(os.environ.get('NN_STRESS_SECONDS', '90'))
STRANDS = CARGO * 50
LOOPS = os.environ.get('NN_STRESS_LOOPS') == '1'
relay = None
chaos = ROOT / 'tools/coop-anything/tools/chaos/chaos.py'

def note(name, **detail):
    checks.append({'check': name, 'time': time.time(), **detail})
    print(name, json.dumps(detail), flush=True)
    persist()

def persist():
    (OUT / 'result.json').write_text(json.dumps({'run_id': run_id, 'checks': checks, 'samples': samples}, indent=2), encoding='utf-8')

def host(ss):
    return next(s for s in ss if s['role'] == 'host')

def monitor(seconds, expected_belts, expected_strands):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        time.sleep(3)
        ss = states()
        if not ready(ss):
            raise RuntimeError('Session lost during load')
        if any(time.time()-(user_dir(role)/'nn_state.json').stat().st_mtime > 15 for role in roles):
            raise RuntimeError('A client stopped reporting for more than 15 seconds')
        h = host(ss)
        if h['conveyors'] != expected_belts or abs(h['cargo_strands'] - expected_strands) > .01:
            raise RuntimeError(f'Host factory inventory mismatch: {h}')
        if any(s['duplicate_belt_ids'] for s in ss):
            raise RuntimeError('Duplicate belt identity')
        if LOOPS and h.get('belt_strands',0) < expected_strands*.5:
            raise RuntimeError(f'Loop fixture is not transporting enough cargo: {h}')
        metrics = []
        for p, role in zip(processes, roles):
            proc = psutil.Process(p.pid)
            metrics.append({'role': role, 'rss_mib': proc.memory_info().rss / 1048576, 'cpu_seconds': sum(proc.cpu_times()[:2])})
        samples.append({'time': time.time(), 'stage_belts': expected_belts, 'states': ss, 'processes': metrics})
        persist()

def rpc(method, **params):
    result = subprocess.run([sys.executable, '-I', str(chaos), 'call', '--rpc-port', str(metadata['rpc']), method, json.dumps(params)], capture_output=True, text=True, check=True)
    return result.stdout

try:
    info = OUT / 'relay.json'
    relay = subprocess.Popen([sys.executable, '-I', str(chaos), 'relay', '--target', '127.0.0.1:27841', '--profile', 'lan', '--seed', '4242', '--info-file', str(info), '--log', str(OUT / 'packets.jsonl')], stdout=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
    deadline = time.monotonic() + 10
    while not info.exists():
        if time.monotonic() > deadline: raise RuntimeError('Relay startup timeout')
        time.sleep(.1)
    metadata = json.loads(info.read_text())
    os.environ['NEEDLENET_CONNECT_PORT'] = str(metadata['listen'])
    for role in roles:
        launch(role)
        time.sleep(2 if role == 'host' else .5)
    ss = wait_for(ready)
    note('FOUR_CLIENTS_READY', seed=host(ss)['seed'])
    command('host', 'fund')
    wait_for(lambda ss: ready(ss) and all(s['money'] == 100000 for s in ss))
    command('guest1', 'buy_tech')
    ss = wait_for(lambda ss: ready(ss) and all(len(s['tech']) > 1 for s in ss) and len({json.dumps(s['tech'],sort_keys=True) for s in ss}) == 1, 40)
    if len({s['money'] for s in ss}) != 1 or host(ss)['money'] >= 100000:
        raise RuntimeError('Shared purchase money mismatch')
    note('SHARED_TECH_PURCHASE', money=host(ss)['money'], tech=host(ss)['tech'])
    command('host', 'grant_guest')
    wait_for(lambda ss: ready(ss) and all(s['broom_owned'] == (s['role']=='guest1') for s in ss), 40)
    note('PERSONAL_TOOLS_ISOLATED')
    if os.environ.get('NN_RENDER_HOST') == '1':
        command('host','stress_view')
        time.sleep(3)
    command('host', 'stress_factory', belts=BELTS, cargo=CARGO, loops=LOOPS)
    ss = wait_for(lambda ss: ready(ss) and host(ss)['factory_job']=='done' and all(s['conveyors']==BELTS for s in ss), 150)
    if LOOPS:
        wait_for(lambda ss: ready(ss) and all(s.get('belt_strands',0)>=STRANDS*.5 for s in ss),60)
    monitor(DURATION, BELTS, STRANDS)
    note('NATIVE_FACTORY_LOAD', belts=BELTS, objects=CARGO, seconds=DURATION, loops=LOOPS)
    if os.environ.get('NN_RENDER_HOST') == '1':
        command('host','capture_factory')
        time.sleep(3)
        image_path=user_dir('host')/'stress-factory.png'
        if not image_path.exists() or not host(states())['drawn_frames']:
            raise RuntimeError('Rendered stress fixture was not captured')
        (OUT/'stress-factory.png').write_bytes(image_path.read_bytes())
    if os.environ.get('NN_STRESS_ONLY') == '1':
        note('ALL_REQUIRED_CHECKS_PASSED')
        sys.exit(0)
    command('host', 'save', disable_autosave=True)
    time.sleep(8)
    checkpoint = host(states())
    saved_heights = hay_values('host')
    save_files = list(user_dir('host').rglob('slot_0*'))
    if not save_files: raise RuntimeError('No checkpoint save file')
    hashes = {str(p.relative_to(user_dir('host'))): hashlib.sha256(p.read_bytes()).hexdigest() for p in save_files if p.is_file()}
    note('CHECKPOINT_WRITTEN', files=hashes)
    rpc('disconnect', duration_ms=5000)
    time.sleep(7)
    wait_for(hay_consistent, 60)
    note('FIVE_SECOND_NETWORK_OUTAGE_RECOVERED')
    rpc('set_profile', profile='bad_wifi')
    monitor(90,BELTS,STRANDS)
    note('LOADED_FACTORY_BAD_WIFI_90_SECONDS')
    rpc('set_profile', profile='lan')
    refresh_id = command('guest2','resync')
    wait_for(lambda ss: hay_consistent(ss) and all(s['conveyors']==BELTS for s in ss) and any(s['role']=='guest2' and s.get('last_command_id')==refresh_id and not s['resync_pending'] and ('complete' in s['status'].lower() or 'завершена' in s['status']) for s in ss), 60)
    note('LARGE_WORLD_RESYNC')
    command('host','money')
    wait_for(lambda ss: ready(ss) and all(s['money']==checkpoint['money']+17 for s in ss), 40)
    original_host = processes.pop(0)
    (OUT/'host-before-crash.log').write_bytes((ROOT/'local/host.log').read_bytes())
    killed_at=time.monotonic()
    original_host.terminate()
    original_host.wait(timeout=15)
    ss = wait_for(lambda ss: all(not s['world'] for s in ss if s['role']!='host'), 90)
    note('ABRUPT_HOST_KILL_GUESTS_EXIT_WORLD', seconds=time.monotonic()-killed_at, guests=[{'role':s['role'],'status':s.get('status'),'phase':s['phase']} for s in ss if s['role']!='host'])
    current_hashes = {name:hashlib.sha256((user_dir('host')/name).read_bytes()).hexdigest() for name in hashes}
    if current_hashes != hashes: raise RuntimeError('Crash modified checkpoint')
    os.environ['NEEDLENET_RESTORE']='1'
    launch('host')
    restarted=processes.pop()
    processes.insert(0,restarted)
    time.sleep(5)
    for role in roles[1:]: command(role,'rejoin')
    ss = wait_for(hay_consistent, 150)
    if any(s['money'] != checkpoint['money'] or s['seed'] != checkpoint['seed'] or s['conveyors'] !=BELTS for s in ss):
        raise RuntimeError('Checkpoint metadata restoration failed')
    restored=hay_values('host')
    if len(restored)!=len(saved_heights) or max(abs(a-b) for a,b in zip(restored,saved_heights))>.0021:
        raise RuntimeError('Checkpoint hay restoration failed')
    if not all(s['broom_owned']==(s['role']=='guest1') for s in ss):
        raise RuntimeError('Personal inventory restoration failed')
    if any(s['tech'] != checkpoint['tech'] for s in ss):
        raise RuntimeError('Shared technologies restoration failed')
    monitor(30,BELTS,STRANDS)
    note('HOST_CRASH_CHECKPOINT_RESTORE', money=host(ss)['money'], unsaved_money_lost=17)
    if os.environ.get('NN_LONG_OUTAGE') == '1':
        before = time.monotonic()
        rpc('disconnect', duration_ms=45000)
        ss = wait_for(lambda ss: all(not s['world'] for s in ss if s['role']!='host'), 90)
        if not host(ss)['world']:
            raise RuntimeError('Host left world on guest network outage')
        note('LONG_OUTAGE_GUEST_TIMEOUT_HOST_SURVIVES', disconnect_seconds=time.monotonic()-before)
        time.sleep(max(0, 47-(time.monotonic()-before)))
        for role in roles[1:]:command(role,'rejoin')
        ss=wait_for(hay_consistent,150)
        monitor(15,BELTS,STRANDS)
        note('LONG_OUTAGE_REJOIN')
    note('ALL_REQUIRED_CHECKS_PASSED')
except Exception as error:
    note('FAILED', error=str(error), traceback=traceback.format_exc())
    raise
finally:
    if relay and relay.poll() is None:
        try:(OUT/'relay-stats.json').write_text(rpc('stats'),encoding='utf-8')
        except Exception:pass
    for role in roles:
        source=ROOT/f'local/{role}.log'
        if source.exists(): (OUT/f'{role}.log').write_bytes(source.read_bytes())
    for p in processes:
        if p.poll() is None:p.terminate()
    for p in processes:p.wait(timeout=15)
    if relay and relay.poll() is None:relay.terminate()
    if relay:relay.wait(timeout=10)
    persist()
    print('EVIDENCE',OUT,flush=True)
