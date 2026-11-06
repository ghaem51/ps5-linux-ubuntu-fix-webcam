#!/usr/bin/env python3
"""Check imported symbol versions against the installed kernel and built modules."""
from pathlib import Path
import subprocess
import platform
import re

dist = Path(__file__).resolve().parent / 'dist'
release = (dist / 'kernel-release').read_text().strip()
if release != platform.release():
    raise SystemExit('Kernel changed: rebuild before installing.')
live_symbols = Path(f'/lib/modules/{release}/build/Module.symvers')
if live_symbols.read_bytes() != (dist / 'kernel.symvers').read_bytes():
    raise SystemExit('Installed kernel symbol table changed: rebuild before installing.')
symbols = {}
for filename in ('kernel.symvers', 'media.symvers'):
    for line in (dist / filename).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2:
            crc, name = fields[:2]
            value = int(crc, 16)
            if name in symbols and symbols[name] != value:
                raise SystemExit(f'Conflicting exported symbol: {name}')
            symbols[name] = value
modules = sorted(dist.glob('*.ko'))
def module_structure_size(module):
    sections = subprocess.check_output(['readelf', '-SW', str(module)], text=True)
    match = re.search(r'\.gnu\.linkonce\.this_module\s+\S+\s+\S+\s+\S+\s+([0-9a-fA-F]+)', sections)
    if not match:
        raise SystemExit(f'Cannot read module structure size: {module}')
    return int(match[1], 16)

reference = next(Path(f'/lib/modules/{release}/kernel').rglob('*.ko'), None)
if reference is None:
    raise SystemExit('Cannot find installed kernel module for structure-size check.')
expected_size = module_structure_size(reference)
expected_vermagic = subprocess.check_output(['modinfo', '-F', 'vermagic', str(reference)], text=True).strip()
if not (dist / 'uvcvideo.ko').is_file():
    raise SystemExit('uvcvideo.ko was not built.')
for module in modules:
    if module_structure_size(module) != expected_size:
        raise SystemExit(f'Module structure size mismatch: {module.name}; preserve kernel BTF configuration and rebuild.')
    vermagic = subprocess.check_output(['modinfo', '-F', 'vermagic', str(module)], text=True)
    if vermagic.strip() != expected_vermagic:
        raise SystemExit(f'Kernel module vermagic differs: {module.name}')
    versions = subprocess.check_output(['modprobe', '--show-modversions', str(module)], text=True)
    if not versions.strip():
        raise SystemExit(f'Missing symbol versions: {module.name}')
    for line in versions.splitlines():
        crc, name = line.split()
        if symbols.get(name) != int(crc, 16):
            raise SystemExit(f'Incompatible import in {module.name}: {name}')
print(f'Checked kernel release, module structure size, and imported symbol CRCs for {len(modules)} modules.')
