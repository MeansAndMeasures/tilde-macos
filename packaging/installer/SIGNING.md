# Sign the Tilde app and installer

Brian runs these commands in Terminal. Preparing this guide did not sign,
notarize, install or publish anything. Commands target the existing standalone
bundle, rather than an Xcode archive. Run each step after the previous check
passes. Do not rebuild the app after certificate signing: the app builder
replaces signatures with ad hoc signatures.

## Location and identities

Change to the actual iCloud distribution root:

````zsh
cd '/Users/bjl/Library/Mobile Documents/com~apple~CloudDocs/MeansAndMeasures/Tilde/tilde-macos'
````

Read-only Keychain inspection on 2026-10-27 found
`Developer ID Application: Brian London (L88QTV2BR3)` and
`Developer ID Installer: Brian London (L88QTV2BR3)`. These are different
certificate purposes. Apple Distribution certificates are not substitutes.
Recheck availability and private-key access in your Terminal session:

````zsh
security find-identity -v -p codesigning
````

````zsh
security find-identity -v -p basic
````

The current `build-desktop/Tilde.app` is ARM64, version 1.0.0, minimum macOS
27.0. The existing `build-desktop/Tilde-1.0.0-local.pkg` is unsigned. A certificate
identity being listed does not prove an Apple-managed entitlement is authorized.

## Preserve the intended entitlements

The owner-supplied `Tilde/Tilde.entitlements` contains iCloud containers,
CloudDocuments, App Attest and hardened-process settings. The inspected local
ad hoc app has no entitlement payload, and no embedded provisioning profile or
processed `.xcent` was found. Do not silently delete settings or copy these app
entitlements onto helper tools and libraries.

Inspect the intended settings:

````zsh
plutil -p Tilde/Tilde.entitlements
````

For a standalone app, establish that the chosen Developer ID team and App ID
authorize the requested capabilities. If Apple requires a Developer ID
provisioning profile for them, use the matching profile at
`build-desktop/Tilde.app/Contents/embedded.provisionprofile` **before** signing,
and the corresponding resolved entitlement plist. Inspect a downloaded profile
with `security cms -D -i '/absolute/path/to/profile.provisionprofile'`. Any
identifier/team/profile mismatch needs resolution in the app's signing setup;
a successful `codesign` alone will not resolve it.

The commands below use the existing plist unchanged. If Xcode produces a
different processed entitlement plist for this identity/profile, substitute its
actual path in both commands. No additional entitlement is invented here.

## Preview, then sign inside out

The latest October 27 recheck found `com.apple.FinderInfo` on the generated app
bundle. Nested code verifies, but this metadata makes strict outer verification
fail. Inspect it first:

````zsh
xattr build-desktop/Tilde.app
````

If that exact attribute is still present, remove only it from this generated app
before signing. This leaves file-provider, provenance and unrelated attributes
untouched; no recursive `xattr -c` is needed for the observed failure.

````zsh
xattr -d com.apple.FinderInfo build-desktop/Tilde.app
````

Then rerun `codesign --verify --deep --strict build-desktop/Tilde.app`. If the
diagnostic names another file or attribute, inspect that exact object before
changing it. The agent has not performed this metadata removal.

The existing script inventories real Mach-O files, skips aliases/symlinks, and
rejects unmapped nested code. Its order is Transcript encoding modules in
`Contents/Resources/transcript`, dylibs in `Contents/Frameworks`, the editor in
`Contents/Helpers`, then the outer app. Signing the app also signs its main
executable and seals resources. Every signature uses hardened runtime and a
secure timestamp; nested code receives no app entitlement plist.

Preview all commands without changing signatures:

````zsh
python3 tools/sign_macos_app.py --app build-desktop/Tilde.app --identity 'Developer ID Application: Brian London (L88QTV2BR3)' --finalize-app --entitlements Tilde/Tilde.entitlements --dry-run
````

After the entitlement/profile setup above is settled, run the same operation:

````zsh
python3 tools/sign_macos_app.py --app build-desktop/Tilde.app --identity 'Developer ID Application: Brian London (L88QTV2BR3)' --finalize-app --entitlements Tilde/Tilde.entitlements
````

Allow the requested Keychain private-key access if Terminal prompts. The script
stops on failure; rerun the complete operation after correcting a cause. It does
not notarize. Do not use `codesign --deep` to sign; `--deep` below is verification.

## Verify the app before packaging

````zsh
python3 tools/sign_macos_app.py --app build-desktop/Tilde.app --verify-only
````

````zsh
codesign --display --verbose=4 --entitlements - build-desktop/Tilde.app
````

Inspect Developer ID authority, TeamIdentifier `L88QTV2BR3`, timestamp, runtime
flags and actual entitlements; verify they match the intended configuration.
Check that the standalone editor still runs:

````zsh
build-desktop/Tilde.app/Contents/Helpers/tilde --version
````

Open the app and repeat New/Open, typing, Save and unsaved-close behavior before
calling the signed app verified. These runtime checks matter because signature
verification does not establish capability access or UI behavior.

## Repackage the signed app, then sign the installer

Rebuild only the installer so its payload contains the newly signed app. This
script verifies the app and uses `pkgbuild`; it does not rebuild or re-sign it.
It replaces the unsigned local package of the same version.

````zsh
python3 tools/build_macos_installer.py
````

Create a separate signed package:

````zsh
productsign --sign 'Developer ID Installer: Brian London (L88QTV2BR3)' --timestamp build-desktop/Tilde-1.0.0-local.pkg build-desktop/Tilde-1.0.0-signed.pkg
````

````zsh
pkgutil --check-signature build-desktop/Tilde-1.0.0-signed.pkg
````

The signature should identify the selected Developer ID Installer certificate
and its Apple trust chain. The package installs `/Applications/Tilde.app` and
`/usr/local/bin/tilde`; none of these preparation commands installs it.

## Distribution boundary

Signing, notarization and Gatekeeper assessment are distinct. A signed package
is not evidence of notarization. Optional read-only assessments are
`spctl --assess --type execute --verbose=4 build-desktop/Tilde.app` and
`spctl --assess --type install --verbose=4 build-desktop/Tilde-1.0.0-signed.pkg`;
rejection before notarization does not by itself indicate a broken signature.
Notarization credentials, submission, stapling, installation and public release
remain separate work. This guide performs none of them automatically.

For Xcode's separate build-phase route, omit `--finalize-app`: Xcode owns the
outer signature and processed entitlements. Do not combine that route with this
standalone finalization sequence. Archive/export remains independently unverified.
