import json, time
from session_support import *
try:
    launch('host')
    time.sleep(2)
    for role in roles[1:]: launch(role)
    wait_for(ready)
    command('guest1', 'resync', corrupt=True)
    wait_for(lambda ss: hay_consistent(ss) and any(s['role']=='guest1' and not s.get('resync_pending') and ('complete' in s.get('status','').lower() or 'завершена' in s.get('status','')) for s in ss), 40)
    print('GUEST_RESYNC_COMPLETE_PASS', flush=True)
    command('host', 'resync')
    wait_for(lambda ss: any(s['role']=='host' and ('sent to 3' in s.get('status','') or '3 игрокам' in s.get('status','')) for s in ss), 30)
    print('HOST_RESYNC_SENT_PASS', flush=True)
    command('guest1', 'resync_timeout')
    wait_for(lambda ss: any(s['role']=='guest1' and not s.get('resync_pending') and ('15 seconds' in s.get('status','') or '15 секунд' in s.get('status','')) for s in ss), 30)
    print('RESYNC_TIMEOUT_RECOVERY_PASS', flush=True)
    command('guest1', 'resync')
    wait_for(lambda ss: any(s['role']=='guest1' and not s.get('resync_pending') and ('complete' in s.get('status','').lower() or 'завершена' in s.get('status','')) for s in ss), 30)
    print('RESYNC_RETRY_PASS', flush=True)
    (ROOT/'local/recovery-result.json').write_text(json.dumps({'checks':['guest_resync','host_sent','timeout_state','retry'],'states':states()},ensure_ascii=False,indent=2),encoding='utf-8')
finally:
    for p in processes:
        if p.poll() is None: p.terminate()
    for p in processes: p.wait(timeout=15)
