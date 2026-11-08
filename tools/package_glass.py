"""Build a reproducible manual-install development archive; never publishes."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
name = 'Decker_v1.50.13_dev_Mutant_X_Floating_Glass.zip'
paths = ['addons/decker/decker.lua', 'LICENSE', 'NOTICE', 'README.md', 'CHANGELOG.md',
         'docs/CONTROLS_1.50.13.md', 'docs/UI_FIXES_1.50.1.md', 'docs/FLOATING_GLASS.md', 'docs/FLOATING_GLASS_SIMULATION.png']
out = root / 'dist' / name
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for path in paths:
        entry = zipfile.ZipInfo(path, (2026, 10, 21, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        z.writestr(entry, (root / path).read_bytes())
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert z.namelist() == paths
    assert z.read(paths[0]) == (root / paths[0]).read_bytes()
    assert b"addon.version = '1.50.13-dev'" in z.read(paths[0])
    assert not any(p.endswith('.cfg') for p in z.namelist())
digest = hashlib.sha256(out.read_bytes()).hexdigest()
out.with_suffix('.zip.sha256').write_text(f'{digest}  {name}\n')
print(f'{out.name}: {out.stat().st_size} bytes; ZIP integrity/source equality PASS; SHA-256 {digest}')
