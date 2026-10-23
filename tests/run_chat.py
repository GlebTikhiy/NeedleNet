import json, time
from session_support import *
try:
    launch('host')
    time.sleep(2)
    for role in roles[1:]: launch(role)
    wait_for(ready)
    for role in roles:
        message = role + ' Привет! [b]буквальный текст[/b] ' + 'я' * 240
        command(role, 'chat', text=message)
        expected = message[:200]
        wait_for(lambda ss: all(any(m['text'] == expected and m['who'] == role for m in s.get('chat', [])) for s in ss), 30)
        print('CHAT_PASS', role, flush=True)
    (ROOT / 'local/chat-result.json').write_text(json.dumps({'passed': roles, 'states': states()}, ensure_ascii=False, indent=2), encoding='utf-8')
finally:
    for p in processes:
        if p.poll() is None: p.terminate()
    for p in processes: p.wait(timeout=15)
