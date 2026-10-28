"""Run the item scenarios behind Co-op Anything's deterministic UDP chaos relay."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[2]
info = root / 'local' / f'chaos-info-{time.time_ns()}.json'
relay = subprocess.Popen([sys.executable, '-I', str(root / 'tools/coop-anything/tools/chaos/chaos.py'), 'relay', '--target', '127.0.0.1:27841', '--profile', 'bad_wifi', '--seed', '4242', '--info-file', str(info), '--log', str(root / 'local/chaos-packets.jsonl')], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, creationflags=subprocess.CREATE_NO_WINDOW)
try:
    deadline = time.monotonic() + 10
    while not info.exists():
        if relay.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('Chaos relay did not start')
        time.sleep(0.1)
    metadata = json.loads(info.read_text())
    env = os.environ.copy()
    env['NEEDLENET_CONNECT_PORT'] = str(metadata['listen'])
    print('CHAOS_PROFILE bad_wifi seed=4242', metadata, flush=True)
    result = subprocess.run([sys.executable, str(root / 'dev/tests/run_items.py')], cwd=root, env=env)
    stats = subprocess.run([sys.executable, '-I', str(root / 'tools/coop-anything/tools/chaos/chaos.py'), 'call', '--rpc-port', str(metadata['rpc']), 'stats'], capture_output=True, text=True)
    (root / 'local/chaos-stats.json').write_text(stats.stdout)
    print('CHAOS_RESULT', result.returncode, flush=True)
    sys.exit(result.returncode)
finally:
    if relay.poll() is None:
        relay.terminate()
    relay.wait(timeout=10)
