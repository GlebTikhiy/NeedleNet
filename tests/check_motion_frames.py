"""Check rendered torso stability, not just scene-graph coordinates.

The motion probe holds the skeleton pose during frames 240..359 while native
movement, camera smoothing and the production view-offset update keep running.
"""
from pathlib import Path
import argparse
import json

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('folder', nargs='?', type=Path, default=Path(__file__).resolve().parents[1] / 'local/motion/current')
args = parser.parse_args()
tops = []
for index in range(42, 59):
    pixels = np.asarray(Image.open(args.folder / f'frame-{index:03d}.png').convert('RGB'), dtype=np.float32)
    region = pixels[300:710, 250:1100]
    red, green, blue = region[:, :, 0], region[:, :, 1], region[:, :, 2]
    ys, _ = np.where((red > 70) & (red > green * 1.6) & (red > blue * 1.5))
    if ys.size < 100:
        raise RuntimeError('Expected the host red avatar in the look-down capture')
    tops.append(int(ys.min()))
span = max(tops) - min(tops)
report = {'frames': len(tops), 'silhouette_top_span_pixels': span, 'limit_pixels': 3}
(args.folder / 'render-stability.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
if span > 3:
    raise RuntimeError('First-person torso still jitters in the rendered frames')
