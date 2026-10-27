#!/usr/bin/env python3
"""Sign Tilde's embedded Mach-O code; let Xcode seal the app, or explicitly finalize it."""
import argparse
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys

CODESIGN = '/usr/bin/codesign'


def inventory(app):
    contents = app/'Contents'
    if not contents.is_dir() or app.suffix != '.app':
        raise ValueError(f'Not an app bundle: {app}')
    info_path = contents/'Info.plist'
    info = plistlib.loads(info_path.read_bytes()) if info_path.exists() else {}
    executable = info.get('CFBundleExecutable') or os.environ.get('EXECUTABLE_NAME', 'Tilde')
    main = contents/'MacOS'/executable
    items = []
    unsupported = []
    for path in contents.rglob('*'):
        if path.is_symlink() or not path.is_file():
            continue
        kind = subprocess.check_output(['/usr/bin/file', '-b', str(path)], text=True)
        if 'Mach-O' not in kind:
            continue
        if path == main:
            continue  # Signing the app bundle signs its main executable.
        relative = path.relative_to(contents)
        if relative.parts[:2] == ('Resources', 'transcript'):
            role, order = 'encoding module', 0
        elif relative.parts[0] == 'Frameworks' and len(relative.parts) == 2:
            role, order = 'library', 1
        elif relative.parts[0] == 'Helpers' and len(relative.parts) == 2:
            role, order = 'helper', 2
        else:
            unsupported.append(str(relative))
            continue
        items.append((order, role, path))
    if unsupported:
        raise ValueError('Unmapped nested code needs its own signing policy: ' + ', '.join(unsupported))
    if not (contents/'Helpers/tilde').is_file():
        raise ValueError('Embedded editor is missing; run the runtime-embedding phase first')
    if not (contents/'Frameworks/libtranscript.dylib').is_file():
        raise ValueError('Embedded libraries are missing; run the runtime-embedding phase first')
    return main, sorted(items, key=lambda item: (item[0], str(item[2])))


def execute(command, dry_run):
    print(shlex.join(str(part) for part in command), flush=True)
    if not dry_run:
        subprocess.run([str(part) for part in command], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, help='App to sign; defaults to the current Xcode target app')
    parser.add_argument('--identity', help='Certificate name or SHA-1; defaults to EXPANDED_CODE_SIGN_IDENTITY')
    parser.add_argument('--finalize-app', action='store_true', help='Standalone only: also sign and verify the outer app')
    parser.add_argument('--entitlements', type=Path, help='Resolved app entitlements for standalone finalization')
    parser.add_argument('--dry-run', action='store_true', help='Print the signing commands without executing them')
    parser.add_argument('--verify-only', action='store_true', help='Verify the completed app without signing it')
    args = parser.parse_args()
    in_xcode = bool(os.environ.get('TARGET_BUILD_DIR') and os.environ.get('WRAPPER_NAME'))
    if os.environ.get('CODE_SIGNING_ALLOWED') == 'NO' and not args.dry_run and not args.verify_only:
        print('Code signing is disabled for this build; no signatures changed.')
        return
    app = args.app
    if app is None:
        if not in_xcode:
            parser.error('Use --app outside an Xcode build phase')
        app = Path(os.environ['TARGET_BUILD_DIR'])/os.environ['WRAPPER_NAME']
    app = app.resolve()
    if args.verify_only:
        if args.finalize_app or args.entitlements:
            parser.error('--verify-only cannot be combined with signing options')
        _, items = inventory(app)
        for _, _, path in items:
            execute([CODESIGN, '--verify', '--strict', '--verbose=2', path], args.dry_run)
        execute([CODESIGN, '--verify', '--deep', '--strict', '--verbose=2', app], args.dry_run)
        return
    identity = args.identity or os.environ.get('EXPANDED_CODE_SIGN_IDENTITY')
    if not identity:
        if args.dry_run:
            identity = '<Xcode signing certificate>'
        else:
            parser.error('Select a signing certificate in Xcode or supply --identity')
    if identity == '-':
        parser.error('This signing step requires a certificate; ad hoc signing is not accepted')
    if args.finalize_app:
        if in_xcode:
            parser.error('Do not use --finalize-app in a build phase; Xcode owns the outer CodeSign step')
        if args.entitlements is None or not args.entitlements.is_file():
            parser.error('--finalize-app requires --entitlements pointing to the intended app entitlement plist')
        entitlements = plistlib.loads(args.entitlements.read_bytes())
        if not isinstance(entitlements, dict):
            parser.error('The entitlement plist must contain a dictionary')
        if b'$(' in args.entitlements.read_bytes() or b'${' in args.entitlements.read_bytes():
            parser.error('Resolve build variables in the entitlement plist before standalone signing')
    elif args.entitlements:
        parser.error('In a build phase, configure CODE_SIGN_ENTITLEMENTS in Xcode instead')
    executable, items = inventory(app)
    if args.finalize_app and not executable.is_file():
        parser.error(f'Main executable is missing: {executable}')
    # Every prerequisite is checked above, before modifying any signature.
    flags = [CODESIGN, '--force', '--sign', identity, '--timestamp', '--options', 'runtime']
    for _, role, path in items:
        print(f'\nSigning {role}: {path.relative_to(app)}', flush=True)
        execute([*flags, path], args.dry_run)
        execute([CODESIGN, '--verify', '--strict', '--verbose=2', path], args.dry_run)
    if args.finalize_app:
        execute([*flags, '--entitlements', args.entitlements.resolve(), app], args.dry_run)
        execute([CODESIGN, '--verify', '--deep', '--strict', '--verbose=2', app], args.dry_run)
    else:
        print(f'\nEmbedded layers complete: {len(items)} code files. Outer app signing is deferred to Xcode.', flush=True)
        print('Xcode will apply its processed entitlements and sign the main executable and resource seal.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Tilde signing failed: {error}', file=sys.stderr)
        sys.exit(1)
