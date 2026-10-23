"""Real-engine regression: predicted seam transfer plus partial source replay.

The targeted replay is synthetic; physical factory coverage is a separate suite.
Set NN_EXPECT_COPIES=2 only to prove the old implementation fails the invariant.
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
    command('guest1','partial_belt_probe')
    file=user_dir('guest1')/'partial-belt-probe.json'
    deadline=time.monotonic()+10
    while not file.exists():
        if time.monotonic()>deadline:raise RuntimeError('Probe never completed')
        time.sleep(.1)
    result=json.loads(file.read_text(encoding='utf-8'))
    expected=int(os.environ.get('NN_EXPECT_COPIES','1'))
    if not result['accepted'] or result['copies']!=expected:
        raise RuntimeError(f'Expected {expected} copy; got {result}')
    label='mutation-old' if expected==2 else 'fixed'
    (ROOT/f'local/belt-partial-{label}.json').write_text(json.dumps(result,indent=2))
    print('PARTIAL_BELT_REPLAY',label,result,flush=True)
finally:
    for p in processes:
        if p.poll() is None:p.terminate()
    for p in processes:p.wait(timeout=15)
