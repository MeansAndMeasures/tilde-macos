#!/usr/bin/env python3
"""Build the desktop frame and embed a fresh Meson-installed runtime."""
import json
import argparse
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build-desktop'

def run(*args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)

def output(*args):
    return subprocess.check_output([str(x) for x in args], text=True)

def dependencies(path):
    return [line.strip().split(' (')[0] for line in output('/usr/bin/otool', '-L', path).splitlines()[1:]]

def app_metadata(version, minimum_os):
    """Preserve the owner's plist and expand generated build values."""
    source = plistlib.loads((ROOT/'Tilde/Info.plist').read_bytes())
    variables = {
        'MACOSX_DEPLOYMENT_TARGET': minimum_os,
        'MARKETING_VERSION': version,
        'CURRENT_PROJECT_VERSION': version,
        'PRODUCT_NAME': 'Tilde',
        'EXECUTABLE_NAME': 'Tilde',
        'PRODUCT_BUNDLE_IDENTIFIER': 'com.MeansAndMeasures.Tilde',
    }

    def expand(value):
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        if isinstance(value, list):
            return [expand(item) for item in value]
        if isinstance(value, str):
            def replace(match):
                name = match.group(1) or match.group(2)
                if name not in variables:
                    raise ValueError(f'Unresolved build variable {name} in Tilde/Info.plist')
                return variables[name]
            return re.sub(r'\$\(([^)]+)\)|\$\{([^}]+)\}', replace, value)
        return value

    info = expand(source)
    defaults = {
        'CFBundleExecutable': 'Tilde',
        'CFBundleIdentifier': variables['PRODUCT_BUNDLE_IDENTIFIER'],
        'CFBundleName': 'Tilde',
        'CFBundleDisplayName': 'Tilde',
        'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': version,
        'CFBundleVersion': version,
        'LSMinimumSystemVersion': minimum_os,
    }
    for key, value in defaults.items():
        info.setdefault(key, value)
    for key in ['CFBundleShortVersionString', 'CFBundleVersion']:
        if info[key] != version:
            raise ValueError(f'{key} in Tilde/Info.plist must match the built editor version {version}')
    declared = tuple(int(part) for part in info['LSMinimumSystemVersion'].split('.'))
    required = tuple(int(part) for part in minimum_os.split('.'))
    if declared < required:
        raise ValueError(f'Tilde/Info.plist declares macOS {info["LSMinimumSystemVersion"]}, but the built code requires {minimum_os}')
    return info

def build():
    OUT.mkdir(exist_ok=True)
    swift_build = Path(os.environ.get('TILDE_SWIFT_BUILD_DIRECTORY', OUT/'swift'))
    env = dict(os.environ, DEVELOPER_DIR='/Library/Developer/CommandLineTools',
               CCACHE_DIR=str(OUT/'ccache'),
               CLANG_MODULE_CACHE_PATH=os.environ.get('CLANG_MODULE_CACHE_PATH', str(OUT/'clang-cache')),
               SWIFT_MODULECACHE_PATH=os.environ.get('SWIFT_MODULECACHE_PATH', str(OUT/'swift-cache')))
    run('/Library/Developer/CommandLineTools/usr/bin/swift', 'build', '--build-system', 'native', '-c', 'release',
        '--scratch-path', swift_build, '--disable-sandbox', cwd=ROOT, env=env)
    swift_bin = Path(subprocess.check_output(['/Library/Developer/CommandLineTools/usr/bin/swift', 'build', '--build-system', 'native', '-c', 'release',
                           '--scratch-path', str(swift_build), '--disable-sandbox', '--show-bin-path'], text=True, env=env).strip())
    options = {entry['name']:entry['value'] for entry in json.loads((ROOT/'build-release/meson-info/intro-buildoptions.json').read_text())}
    if not options.get('installed_runtime'):
        raise RuntimeError('build-release must use installed_runtime=true')
    meson = shutil.which('meson') or '/opt/homebrew/bin/meson'
    run(meson, 'compile', '-C', ROOT/'build-release', 'tilde', env=env)
    version = json.loads((ROOT/'build-release/meson-info/intro-projectinfo.json').read_text())['version']
    with tempfile.TemporaryDirectory(prefix='tilde-desktop-') as temporary:
        temp = Path(temporary)
        run(meson, 'install', '-C', ROOT/'build-release', '--no-rebuild', '--destdir', temp/'stage', env=env)
        stage = temp/'stage'/str(options['prefix']).lstrip('/')
        app = temp/'Tilde.app'
        contents = app/'Contents'
        frameworks = contents/'Frameworks'
        helpers = contents/'Helpers'
        resources = contents/'Resources'
        for folder in [frameworks, helpers, resources, contents/'MacOS']:
            folder.mkdir(parents=True, exist_ok=True)
        shutil.copy2(swift_bin/'Tilde', contents/'MacOS/Tilde')
        for bundle in swift_bin.glob('*.bundle'):
            shutil.copytree(bundle, resources/bundle.name)
        shutil.copy2(stage/options['bindir']/'tilde', helpers/'tilde')
        lib = stage/options['libdir']
        for dylib in lib.glob('*.dylib'):
            shutil.copy2(dylib, frameworks/dylib.name)
        shutil.copytree(lib/'transcript', resources/'transcript', symlinks=True)
        for directory in (stage/options['datadir']).iterdir():
            if directory.is_dir():
                shutil.copytree(directory, resources/directory.name, symlinks=True)
        licenses = resources/'licenses/SwiftTerm'
        licenses.mkdir(parents=True)
        shutil.copy2(ROOT/'third_party/SwiftTerm/LICENSE', licenses/'LICENSE')
        binaries = [helpers/'tilde', *frameworks.glob('*.dylib'),
                    *[p for p in (resources/'transcript').glob('*.ltc') if not p.is_symlink()]]
        # Close the dependency graph before rewriting any load commands.
        for binary in binaries:
            for dependency in dependencies(binary):
                if dependency.startswith('/opt/homebrew/'):
                    target = frameworks/Path(dependency).name
                    if not target.exists():
                        shutil.copy2(dependency, target)
                        binaries.append(target)
        for binary in binaries:
            for dependency in dependencies(binary):
                if dependency.startswith(('/usr/lib/', '/System/')):
                    continue
                target = frameworks/Path(dependency).name
                if not target.exists():
                    raise RuntimeError(f'Unresolved dependency {dependency} in {binary}')
                if dependency != '@rpath/'+target.name:
                    run('/usr/bin/install_name_tool', '-change', dependency, '@rpath/'+target.name, binary)
            if binary.suffix == '.dylib':
                run('/usr/bin/install_name_tool', '-id', '@rpath/'+binary.name, binary)
            rpaths = re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset', output('/usr/bin/otool','-l',binary))
            for path in rpaths:
                run('/usr/bin/install_name_tool','-delete_rpath',path,binary)
            rpath = '@loader_path/../Frameworks' if binary.parent == helpers else '@loader_path/../../Frameworks' if binary.parent.name == 'transcript' else '@loader_path'
            run('/usr/bin/install_name_tool','-add_rpath',rpath,binary)
            run('/usr/bin/codesign','--force','--sign','-',binary)
        minimum_versions = ['13.0']
        for binary in [contents/'MacOS/Tilde', *binaries]:
            minimum_versions.extend(re.findall(r'\bminos\s+([\d.]+)', output('/usr/bin/otool', '-l', binary)))
        minimum_os = max(minimum_versions, key=lambda version: tuple(int(part) for part in version.split('.')))
        info = app_metadata(version, minimum_os)
        icon = ROOT/'icons/Tilde.icns'
        if icon.exists():
            shutil.copy2(icon, resources/icon.name)
            info.setdefault('CFBundleIconFile', icon.name)
        (contents/'Info.plist').write_bytes(plistlib.dumps(info))
        run('/usr/bin/codesign','--force','--sign','-',app)
        run('/usr/bin/codesign','--verify','--deep','--strict',app)
        run(helpers/'tilde','--version', env=dict(os.environ, DYLD_LIBRARY_PATH='', DYLD_FALLBACK_LIBRARY_PATH=''))
        for binary in binaries:
            loads = dependencies(binary)
            if any(not x.startswith(('@rpath/','/usr/lib/','/System/')) for x in loads):
                raise RuntimeError(f'Nonportable load commands in {binary}: {loads}')
        final = OUT/'Tilde.app'
        if final.exists():
            backup = OUT/'Tilde.previous.app'
            if backup.exists():
                shutil.rmtree(backup)
            final.rename(backup)
        shutil.copytree(app, final, symlinks=True)
        print(final)
        return final

def embed_for_xcode(app, contents):
    """Copy runtime/resources; leave Xcode's executable, plist and signing intact."""
    contents = Path(contents).resolve()
    if contents.name != 'Contents' or contents.parent.suffix != '.app':
        raise ValueError('--xcode-contents must name the Contents directory of an app bundle')
    for name in ['Helpers', 'Frameworks', 'Resources']:
        shutil.copytree(app/'Contents'/name, contents/name, symlinks=True, dirs_exist_ok=True)
    print(f'Embedded runtime in {contents}; final signing remains the caller\'s responsibility')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xcode-contents', type=Path,
                        help='Also embed runtime/resources into this Xcode app Contents directory')
    args = parser.parse_args()
    app = build()
    if args.xcode_contents:
        embed_for_xcode(app, args.xcode_contents)
