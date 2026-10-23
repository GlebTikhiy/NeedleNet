from session_support import *
import sys
import shutil

try:
    for role in roles:
        launch(role)
        time.sleep(3 if role == 'host' else 1)
    wait_for(ready)
    command('host', 'factory_line')
    wait_for(lambda ss: ready(ss) and all(s['conveyors'] == 8 for s in ss), 60)
    print('EIGHT_CONVEYOR_BUILD_SYNC_PASS', flush=True)
    command('host', 'factory_fill')
    populated = wait_for(lambda ss: ready(ss) and all(len(s['belt_records']) >= 80 for s in ss), 40)
    print('LOADED_BELT_REPLICATION_PASS', [len(s['belt_records']) for s in populated], flush=True)
    baseline = {r['seq']: r['s'] for r in next(s for s in populated if s['role'] == 'host')['belt_records']}
    wait_for(lambda ss: ready(ss) and any(r['seq'] in baseline and r['s'] > baseline[r['seq']] + 0.2 for r in next(s for s in ss if s['role'] == 'host')['belt_records']), 20)
    print('BELT_CARGO_MOVEMENT_PASS', flush=True)
    for sample in range(8):
        time.sleep(3)
        ss = states()
        if not ready(ss):
            raise RuntimeError('Session lost while transporting cargo')
        for s in ss:
            sequences = [r['seq'] for r in s['belt_records']]
            if len(sequences) != len(set(sequences)):
                raise RuntimeError('Duplicate belt record identity')
    print('LOADED_BELTS_NO_DUPLICATE_IDS_PASS', flush=True)
    subprocess.run([sys.executable, str(ROOT / 'tests/check_factory_log.py')], check=True)
    shutil.copyfile(ROOT / 'local/host.log', ROOT / 'local/factory-host.log')
    (ROOT / 'local/factory-result.json').write_text(json.dumps({'states': states(), 'checks': ['eight_conveyors', 'physical_cargo_replication', 'cargo_movement', 'no_duplicate_sequences', 'host_quantity_conservation'], 'fixture_objects': 160, 'strands_per_object': 50}, indent=2))
finally:
    for p in processes:
        if p.poll() is None:
            p.terminate()
    for p in processes:
        p.wait(timeout=15)
