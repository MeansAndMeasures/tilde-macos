#!/usr/bin/env python3
"""Package the verified desktop app plus its direct command-line entry point."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
app = ROOT/'build-desktop/Tilde.app'
if not app.exists():
    raise SystemExit('Build Tilde.app with tools/build_macos_app.py first')
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(app)],check=True)
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
with tempfile.TemporaryDirectory(prefix='tilde-installer-') as temporary:
    root = Path(temporary)/'root'
    (root/'Applications').mkdir(parents=True)
    shutil.copytree(app,root/'Applications/Tilde.app',symlinks=True)
    command = root/'usr/local/bin'
    command.mkdir(parents=True)
    (command/'tilde').symlink_to('/Applications/Tilde.app/Contents/Helpers/tilde')
    components = Path(temporary)/'components.plist'
    subprocess.run(['/usr/bin/pkgbuild','--analyze','--root',str(root),str(components)],check=True)
    settings = plistlib.loads(components.read_bytes())
    for component in settings:
        component['BundleIsRelocatable'] = False
        component['BundleHasStrictIdentifier'] = True
    components.write_bytes(plistlib.dumps(settings))
    pkg = ROOT/'build-desktop'/f"Tilde-{info['CFBundleShortVersionString']}-local.pkg"
    subprocess.run(['/usr/bin/pkgbuild','--root',str(root),'--identifier','com.MeansAndMeasures.Tilde',
        '--version',info['CFBundleShortVersionString'],'--install-location','/',
        '--component-plist',str(components), '--scripts',str(ROOT/'packaging/installer/scripts'),str(pkg)],check=True)
    print(pkg)
