"""Build a minimal, auditable player ZIP using only the Python standard library."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parent
NAME = 'NeedleNet-0.1.0-preview.1-Windows'
PLAYER_FILES = (
    'Install.cmd', 'Install.ps1', 'LICENSE', 'NOTICE.md',
    'README.md', 'README-RU.md', 'CHANGELOG.md',
    'docs/INSTALL.md', 'docs/CREATORS.md', 'media/banner.svg',
)
RUNTIME_SUFFIXES = {'.gd', '.gdextension', '.glb', '.png', '.svg'}


def build():
    version = re.search(r'const VERSION\s*:?=\s*"([^"]+)"', (ROOT / 'mods/multiplayer/mp.gd').read_text(encoding='utf-8'))
    if not version or version[1] != '0.1.0-preview.1':
        raise RuntimeError('Update release metadata for the current runtime version')
    files = [ROOT / name for name in PLAYER_FILES]
    for path in sorted((ROOT / 'mods/multiplayer').rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        if (path.suffix in RUNTIME_SUFFIXES
                or relative == 'mods/multiplayer/tool_poses.cfg'
                or relative == 'mods/multiplayer/models/CREDITS.txt'):
            files.append(path)
        else:
            raise RuntimeError(f'Unexpected runtime file: {relative}')
    manifest = []
    for path in files:
        if not path.is_file() or path.is_symlink():
            raise RuntimeError(f'Missing or linked release file: {path.name}')
        relative = path.relative_to(ROOT).as_posix()
        raw = path.read_bytes()
        if path.suffix in {'.gd', '.gdextension', '.md', '.ps1', '.cmd', '.cfg', '.txt'}:
            text = raw.decode('utf-8-sig')
            if re.search(r'(?i)(?:[A-Z]:[\\/](?:Users|Shared)[\\/]|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)', text):
                raise RuntimeError(f'Private path or credential marker: {relative}')
        manifest.append({'path': relative, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
    output = ROOT / 'dist'
    output.mkdir(exist_ok=True)
    archive = output / (NAME + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as target:
        for path in files:
            info = zipfile.ZipInfo(NAME + '/' + path.relative_to(ROOT).as_posix(), (2026, 10, 23, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            target.writestr(info, path.read_bytes())
        info = zipfile.ZipInfo(NAME + '/MANIFEST.json', (2026, 10, 23, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        target.writestr(info, json.dumps({'version': version[1], 'files': manifest}, indent=2) + '\n')
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n', encoding='ascii')
    with zipfile.ZipFile(archive) as check:
        if check.testzip() is not None:
            raise RuntimeError('Archive CRC check failed')
        if len(check.namelist()) != len(files) + 1:
            raise RuntimeError('Unexpected archive entries')
    print(f'{archive}\n{len(files) + 1} entries; SHA-256 {digest}')
    return archive


if __name__ == '__main__':
    build()
