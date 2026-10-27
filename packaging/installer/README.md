# Local Tilde app and installer

From the distribution root, run `python3 tools/build_macos_app.py`, then
`python3 tools/build_macos_installer.py`. The app build uses the existing
`build-release` Meson configuration with `installed_runtime=true` and the
installed Apple command-line toolchain. Swift and C compiler caches stay under
`build-desktop`; Swift sources and the pinned rendering library require no
network fetch at build time.

Open `build-desktop/Tilde.app` to start a blank document. Its File menu opens
files and creates new windows. Finder's Open With can pass text documents to
Tilde. The editing process runs directly inside the app window.

The installer installs `/Applications/Tilde.app` and a symlink from
`/usr/local/bin/tilde` to `/Applications/Tilde.app/Contents/Helpers/tilde`.
Calling that command from a terminal keeps the editor in that terminal.
The preinstall script refuses to overwrite an unrelated existing command.

The installer is unsigned. The app has an ad hoc signature for local testing.
Final signing, notarization, and system installation are deliberately pending.
The version and minimum supported macOS are taken from the actual build.

Brian's [user-run signing guide](SIGNING.md) covers the existing inside-out
signer, entitlement/profile prerequisites, app verification, repackaging and
Developer ID Installer signing. Preparing those instructions does not change
the signing state of any artifact.

The existing Packages GUI project is still a work in progress. The checked
local installer is generated with Apple's `pkgbuild`; no completed Packages
GUI configuration is claimed here.

The app builder reads `Tilde/Info.plist` as authoritative metadata, recursively
expands supported build variables, and supplies missing bundle/build identifiers.
Services, document types, URL schemes, and other owner-supplied settings survive
unchanged. Conflicting explicit version/minimum-OS values produce an error.

For Xcode embedding, pass `--xcode-contents` with the target app Contents path.
The builder copies Helpers, Frameworks, and Resources into that target; it
preserves Xcode's executable and generated Info.plist. This mode does not apply
final signatures to the Xcode target.
