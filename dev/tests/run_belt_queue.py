"""Full snapshot queued before a newer partial destination update.

Real engine replay; deliberately synthetic ordering, separate from load evidence.
NN_EXPECT_COPIES=2 is only for reproducing preview.4's broken invariant.
"""
from session_support import *
try:
    for role in roles:
        launch(role)
        time.sleep(2 if role=='host' else .5)
    wait_for(ready)
    command('host','factory_line')
    wait_for(lambda ss: ready(ss) and all(s['conveyors']==8 for s in ss),60)
    command('host','factory_fill')
    wait_for(lambda ss: ready(ss) and all(s['belt_cargo_count']>=80 for s in ss),40)
    command('guest1','queued_belt_probe')
    file=user_dir('guest1')/'queued-belt-probe.json'
    deadline=time.monotonic()+15
    while not file.exists():
        if time.monotonic()>deadline:raise RuntimeError('Queue probe never completed')
        time.sleep(.1)
    result=json.loads(file.read_text(encoding='utf-8'))
    expected=int(os.environ.get('NN_EXPECT_COPIES','1'))
    if not result['accepted'] or result['copies']!=expected:
        raise RuntimeError(f'Expected {expected} copy; got {result}')
    if expected==1 and not result.get('invalid_rejected'):
        raise RuntimeError('Invalid merged snapshot was allowed to mutate live cargo')
    label='preview4-old' if expected==2 else 'fixed'
    (ROOT/f'local/belt-queue-{label}.json').write_text(json.dumps(result,indent=2))
    print('QUEUED_BELT_REPLAY',label,result,flush=True)
finally:
    for p in processes:
        if p.poll() is None:p.terminate()
    for p in processes:p.wait(timeout=15)
