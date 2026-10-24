"""Prove the partial-belt regression distinguishes old and fixed runtime.

Uses only the isolated lab copy and restores the fixed file even on failure.
The upstream revision is a local Git object; no network or player install edits.
"""
from pathlib import Path
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
source=ROOT if (ROOT/'mods/multiplayer').is_dir() else ROOT/'public/NeedleNet'
relative='mods/multiplayer/mp_belts.gd'
lab=ROOT/'lab/game'/relative
fixed=(source/relative).read_bytes()
old=subprocess.check_output(['git','-C',str(source),'show','v0.1.0-preview.3:'+relative])
if old==fixed:raise RuntimeError('No changed implementation to test')
try:
    for label,raw,copies in [('mutation-old',old,2),('fixed',fixed,1)]:
        lab.write_bytes(raw)
        env=os.environ.copy()
        env['NN_EXPECT_COPIES']=str(copies)
        subprocess.run([sys.executable,str(ROOT/'tests/run_belt_partial.py')],cwd=ROOT,env=env,check=True)
        print('MUTATION_PAIR_PASS',label,flush=True)
finally:
    lab.write_bytes(fixed)
