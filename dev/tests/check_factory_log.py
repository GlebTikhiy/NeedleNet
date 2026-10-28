"""Check conserved cargo in the host's recorded physical-conveyor scenario."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
samples = []
for line in (root / 'local/host.log').read_text(encoding='utf-8-sig').splitlines():
    if not line.startswith('NN_STATE '):
        continue
    state = json.loads(line[9:])
    if state.get('conveyors') != 8:
        continue
    records = state.get('belt_records', [])
    props = state.get('props', {})
    quantity = sum(row['strands'] for row in records) + sum(item['strands'] for item in props.values())
    if quantity:
        if quantity != 8000:
            raise RuntimeError(f'Host cargo conservation failed: {quantity}, expected 8000')
        samples.append({'records': len(records), 'props': len(props), 'strands': quantity})
if len(samples) < 4:
    raise RuntimeError('Not enough loaded factory samples')
(root / 'local/factory-conservation.json').write_text(json.dumps(samples, indent=2))
print(f'HOST_CARGO_CONSERVATION_PASS samples={len(samples)} strands=8000')
