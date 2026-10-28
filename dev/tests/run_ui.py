import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[2]
game = root / 'lab/game'
output = root / 'local/ui'
output.mkdir(parents=True, exist_ok=True)
log = root / 'local/ui-final.log'
env = os.environ.copy()
env.update(APPDATA=str(root / 'local/profiles' / f'ui-{time.time_ns()}'), NEEDLENET_TEST='1', NEEDLENET_UI_OUT=str(output))
fixtures = list((root / 'local/profiles').glob('*/host/Godot/app_userdata/Haystack Incremental/saves/slot_0.dat'))
if fixtures:
    env['NEEDLENET_UI_SAVE'] = str(max(fixtures, key=lambda p: p.stat().st_mtime).resolve())
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = subprocess.SW_HIDE
process = subprocess.Popen([str(game / 'FindTheNeedle.exe'), '--windowed', '--resolution', '1280x720', '--script', str(root / 'dev/tests/ui_test.gd'), '--log-file', str(log)], cwd=game, env=env, startupinfo=startup)
try:
    code = process.wait(timeout=180)
    content = log.read_text(encoding='utf-8-sig')
    for line in content.splitlines():
        if line.startswith('NN_UI_'):
            print(line, flush=True)
    if code or 'NN_UI_RESULT PASS' not in content:
        raise RuntimeError(f'UI run failed, exit={code}; see {log}')
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=15)
