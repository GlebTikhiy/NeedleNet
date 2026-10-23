"""Graceful exit must finish with exit code zero, without forced termination."""
from session_support import *
try:
    for role in roles:
        launch(role)
        time.sleep(2 if role=='host' else .5)
    wait_for(ready)
    for role,p in zip(roles[1:],processes[1:]):
        command(role,'quit_test')
        code=p.wait(timeout=20)
        if code!=0:raise RuntimeError(f'{role} exit={code}')
    live_host=processes[0]
    command('host','quit_test')
    code=live_host.wait(timeout=20)
    if code!=0:raise RuntimeError(f'host exit={code}')
    (ROOT/'local/shutdown-result.json').write_text(json.dumps({'exit_codes':[p.returncode for p in processes]}))
    print('FOUR_GRACEFUL_EXITS_PASS',flush=True)
finally:
    for p in processes:
        if p.poll() is None:p.terminate()
    for p in processes:p.wait(timeout=15)
