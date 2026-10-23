import os
import json
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
game = root / 'lab/game'
output = root / 'local/motion' / os.environ.get('NEEDLENET_MOTION_LABEL', 'current')
output.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(root / 'local/profiles' / f'motion-{time.time_ns()}'), NEEDLENET_TEST='1', NEEDLENET_UI_OUT=str(output))
env['NEEDLENET_VIEW_DRIVER'] = str(root / 'tests/motion_view_driver.gd')
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = subprocess.SW_HIDE
log = output / 'probe.log'
process = subprocess.Popen([str(game / 'FindTheNeedle.exe'), '--windowed', '--resolution', '1280x720', '--script', str(root / 'tests/motion_probe.gd'), '--log-file', str(log)], cwd=game, env=env, startupinfo=startup)
try:
    code = process.wait(timeout=150)
    lines = log.read_text(encoding='utf-8-sig')
    for line in lines.splitlines():
        if line.startswith('NN_PROBE_'):
            print(line, flush=True)
    if code or 'NN_PROBE_RESULT PASS' not in lines:
        raise RuntimeError(f'Motion probe failed: {log}')
    samples = json.loads((output / 'samples.json').read_text(encoding='utf-8'))
    maximum = max(sum(value * value for value in sample['view_error']) ** 0.5 for sample in samples[20:])
    speeds = [sample['speed'] for sample in samples]
    if maximum > 0.001 or max(speeds) < 6 or not any(3 < speed < 5 for speed in speeds):
        raise RuntimeError(f'Local motion regression: view drift={maximum}, max speed={max(speeds)}')
    print(f'NN_PROBE_VIEW_ALIGNMENT_PASS max={maximum:.6f} m', flush=True)
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=15)
