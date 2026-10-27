# Tilde macOS app and installer

Status reconciled 2026-10-27. This is the current implementation note; work
selection and completion belong to the hub's canonical master TODO.

Current behavior is authoritative: `tilde [file]` edits inside the calling
terminal. Desktop launch opens the given file, or a blank document, in Tilde's
own window. No external terminal app or shell is launched by the desktop frame.

## Implemented and checked locally

- AppKit frame hosts the existing Meson-built editor through SwiftTerm's local
  process view. SwiftTerm v1.20.0 is pinned and vendored with its MIT license.
- New and Open create desktop editor windows. File arguments and the macOS
  open-files delegate are handled by the frame.
- Native Save sends the existing editor's save action. Close and Quit request
  the editor's own exit action, retaining its unsaved-change handling.
- Meson performs a fresh staged install. The app build embeds the editor, all
  six component libraries, Homebrew leaf-library dependency closure, key and
  highlight data, configuration, licenses, and Transcript converters/aliases.
- Transcript converters and aliases remain colocated under
  `Contents/Resources/transcript`. Runtime lookup and module RPATHs match this
  placement. This replaces the earlier Frameworks/transcript specification;
  the earlier placement failed bundle-signature validation for aliases.txt.
- Runtime load commands use bundle-relative paths. The helper's RPATH is
  `@loader_path/../Frameworks`; converter modules use
  `@loader_path/../../Frameworks`.
- The app's minimum OS is derived from its built Mach-O components. The current
  editor build requires macOS 27.0, and the generated app advertises 27.0.
- Local ad hoc signature verification and relocated executable checks pass.
- Desktop blank-document launch, opening a Unicode test file, typing, saving,
  and the unsaved-change close prompt were exercised in the running app.
- The embedded helper opened a file and exited in the calling terminal.
- The installer payload contains the app at /Applications/Tilde.app and the
  direct /usr/local/bin/tilde symlink. App relocation is disabled in the package.
- The preinstall guard accepts an absent command or the intended symlink and
  rejects foreign files and foreign dangling symlinks.

## Build outputs

`tools/build_macos_app.py` produces `build-desktop/Tilde.app`.
`tools/build_macos_installer.py` produces an unsigned local installer using the
actual Meson version, currently `build-desktop/Tilde-1.0.0-local.pkg`.

The Xcode native target references the local SwiftTerm package product.
The verified complete bundle is produced by the app-build command above;
Xcode archive/export integration has not been validated in this run.

## Remaining boundary

Final signing is paused at the user's explicit instruction. Developer ID
application/installer signing, notarization, public release, and system-wide
installation have not been performed. Product, app build, and installer
versions are aligned at 1.0.0.

## Verification checkpoint — 2026-10-27

The existing `build-desktop/Tilde.app` passed `codesign --verify --deep --strict`
during the initial audit. A later same-day recheck verifies nested code but
rejects the outer app because `com.apple.FinderInfo` is attached to the bundle.
No metadata was removed. The signing guide includes a targeted user-run remedy;
strict verification must pass again before the app is called currently verified.
Both its frame and embedded editor are ARM64 Mach-O executables; the helper's
`--version` reports 1.0.0. Its inspected dependencies use `@rpath` or system
paths. The actual Info.plist declares minimum macOS 27.0. The existing
`Tilde-1.0.0-local.pkg` is unsigned. These checks inspected existing outputs;
they do not establish a fresh source build or repeat the earlier UI exercises.

The Xcode project passes plist syntax validation and contains native component
targets plus T3Generated/T3Libraries aggregates. A complete applied Debug and
Release verification and archive/export remain separate from that syntax check.
Meson currently registers only `tilde-version`; the retained October 13 test log
reports 0.1.0 and is not current 1.0.0 release coverage.

The distribution has meaningful staged, modified and untracked work. Existing
app artifacts do not establish that a clean checkout reproduces them. Canonical
component pins are under `deps/`; the sibling working clones contain different
revisions in several cases. Do not substitute them silently.

Brian will perform certificate signing. See
[the user-run signing guide](packaging/installer/SIGNING.md) for nested code,
outer app and installer commands and the entitlement/profile boundary. Signing
guidance is prepared; certificate signing and notarization are not completed.
