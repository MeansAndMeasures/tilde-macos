# macOS app target, launcher, bundling, and installer — roadmap

Running checklist for turning the `Tilde` native SwiftUI target into a real,
self-contained, Developer-ID-signed `.app` with a terminal-launcher front end
and an installer. Checked items are done and verified, not just started.
Update this file in the same commit as the work it tracks.

Release version is locked at **1.0.0** (git tag `v1.0.0`); Meson, CLI/About
output, Xcode marketing version, installer metadata, and release filenames
all converge on it.

## Key decisions on record

- The "fixed-prefix executable" problem is **4 separate compiled artifacts**
  (`tilde`, `libt3key`, `libt3highlight`, `libtranscript`), each with its own
  compile-time-baked absolute resource path — not one binary.
- `libunistring`, `libintl`, `libpcre2-8` are the 3 Homebrew leaf libraries
  currently linked by absolute `/opt/homebrew/...` path; those (not
  `ncursesw`, which is a real macOS system library) are what must be vendored
  into `Contents/Frameworks` and re-homed to `@rpath`.
- `libtranscript`'s `.ltc` converter modules and `aliases.txt` resolve
  through the *same* search-path call at runtime and are already installed
  to the same directory by Meson today, so they must stay colocated under
  `Contents/Frameworks/transcript/` in the bundle — not split across
  `Resources/`+`Frameworks/` as first sketched.
- v1 terminal adapters: **Apple Terminal, kitty, ghostty, Rio** (+ its
  nightly/canary build). Stubbed for later: **iTerm2, Warp**. Windows
  Terminal/Console Host are out of scope for this Xcode target entirely.
- Execution ownership is split by risk, not by workstream: mechanical/
  low-judgment code (Workstream A, Workstream D) is written directly;
  anything signing/entitlements/build-integrity-adjacent (B, C's Xcode-side
  wiring, E, F, G) is spec'd exactly and typed by hand in Xcode/Packages.app
  by the project owner, so every setting is one they can defend under
  review.
- `CODE_SIGN_IDENTITY = "Apple Distribution"` and
  `PRODUCT_BUNDLE_IDENTIFIER = com.MeansAndMeasures.Tilde` are both correct
  as already configured — confirmed, not open questions.

Full rationale for all of the above: `/Users/bjl/.claude/plans/dapper-juggling-nautilus.md`.

## 1. Xcode app target

- [x] `Tilde` native SwiftUI target added beside the existing `Tilde-MacOS`
      external Meson build target, bundle id `com.MeansAndMeasures.Tilde`.

## Workstream A — Runtime resource/library relocation

- [x] `t3_shared_bundle_path()` helper added (`deps/t3shared/src/macos_bundle_path.h`):
      dladdr + realpath, Darwin-only, no-op elsewhere.
- [x] Wired into all 4 call sites, each falling back to the existing
      compiled-in default outside a bundle:
  - [x] `tilde` (`src/option.cc`) — `Contents/Resources/tilde`
  - [x] `libt3key` (`deps/t3key/src/key.c`) — `Contents/Resources/libt3key`
  - [x] `libt3highlight` (`deps/t3highlight/src/io.c`) — `Contents/Resources/libt3highlight`
  - [x] `libtranscript` (`deps/transcript/src/{transcript,aliases}.c`) — `Contents/Frameworks/transcript`
- [x] `include_directories` updated in the 4 affected `meson/*/meson.build` files.
- [x] Means+Measures copyright line added to every materially-modified
      upstream file (`option.cc`, `key.c`, `io.c`, `transcript.c`,
      `aliases.c`, `transcript_internal.h`).
- [x] Verified: `meson compile -C build-release tilde` clean, `meson test
      tilde-version` passes, dev-tree fallback behavior unchanged.
- [x] Committed: 4 submodule commits (`t3key`, `t3highlight`, `transcript`,
      `t3shared`) + 1 parent commit pinning them, tagged
      `checkpoint/workstream-a-resource-relocation`.

## Workstream B — Packaging-time library relocation script

- [ ] `packaging/embed-frameworks.sh`: copy component dylibs + `transcript/*.ltc`
      modules from the Meson install tree into `Contents/Frameworks`.
- [ ] Resolve and copy the 3 Homebrew leaf deps (`libunistring`, `libintl`,
      `libpcre2-8`) into `Contents/Frameworks`.
- [ ] `install_name_tool -id @rpath/<name>` on every copied dylib.
- [ ] `install_name_tool -change` on every dependent load command (the
      `tilde` binary + any dylib depending on another).
- [ ] Normalize `tilde`'s `LC_RPATH` list to a single
      `@loader_path/../../Frameworks`.
- [ ] Re-sign everything the script touches, before Xcode's own bundle
      signing pass.
- [ ] Verified: `otool -L`/`otool -l` on the final bundle show zero
      `/opt/homebrew` or build-tree paths; `codesign --verify --deep --strict`
      passes.

## Workstream C — Meson invocation from Xcode

- [ ] Run Script phase on `Tilde` (before Compile Sources): `meson setup
      --reconfigure -Dinstalled_runtime=true -Dbuildtype=<config>
      -Dprefix=<staging dir>` + `meson install --destdir=<staging>` for both
      Debug and Release.
- [ ] Confirm nothing is copied from the old `/private/tmp/tilde-release-test`
      ad hoc install.
- [ ] Bump `meson.build` project version `0.1.0` → `1.0.0`.
- [ ] Align Xcode Debug `MARKETING_VERSION` to `1.0.0` (Release already is).

## Workstream D — The Swift launcher

- [ ] `TerminalAdapter.swift` — protocol + the 3 concrete adapter shapes
      (document-open / `open -na --args` / direct-binary invocation).
- [ ] `TerminalRegistry.swift` — Apple Terminal, kitty, ghostty, Rio, plus
      `.followDefault`.
- [ ] `TerminalPreference.swift` — `UserDefaults` wrapper.
- [ ] `DefaultTerminalResolver.swift` — `NSWorkspace.urlForApplication(toOpen:)`
      lookup for `.command` files.
- [ ] `EditorLauncher.swift` — resolve → attempt launch → fall back to chooser
      on failure.
- [ ] `TerminalChooserView.swift` + `SettingsView.swift` (SwiftUI).
- [ ] `TildeApp.swift` gets the `Settings { SettingsView() }` scene;
      `ContentView.swift`'s placeholder replaced with launcher chrome.
- [ ] Verified: each of the 4 v1 adapters actually opens a window running
      `tilde <file>`; Settings choice + "Follow Default" persist across
      relaunch; `tilde <file>` from an existing terminal never opens the
      chooser or another terminal window (bundle-layout guarantee, not
      launcher logic — see Workstream E).

## Workstream E — Bundle layout & build phases (Xcode)

- [ ] Build phase order on `Tilde`: Run Script (Meson) → Compile Sources →
      Copy Files (`Wrapper`/`Contents/Helpers`, the `tilde` executable) →
      Copy Files (`Frameworks`, Code Sign On Copy) → Copy Bundle Resources.
- [ ] `ARCHS = arm64`.
- [ ] `SKIP_INSTALL = NO`, `INSTALLATION_DIRECTORY = $(LOCAL_APPS_DIR)`.
- [ ] Resources laid out per spec: `tilde/base.config`, `libt3key/`,
      `libt3highlight/`, `licenses/`.

## Workstream F — Scheme & Archive

- [ ] Shared `Tilde.xcscheme` actually saved under `xcshareddata/xcschemes`
      (referenced by the scheme-management plist but not yet on disk).
  - [ ] Build: `Tilde` app target only.
  - [ ] Run: Debug config, executable = `Tilde.app`.
  - [ ] Archive: Release config, Reveal Archive in Organizer enabled.
- [ ] `Tilde-MacOS.xcscheme` left untouched for direct editor/Meson dev work.
- [ ] Developer ID Application certificate present in Xcode → Settings →
      Accounts → Manage Certificates (currently missing).
- [ ] `Product → Archive` succeeds.

## Workstream G — Installer (guided, built by hand in Packages.app)

- [ ] `packaging/installer/scripts/preinstall` — abort install if
      `/usr/local/bin/tilde` exists and isn't already a symlink to
      `/Applications/Tilde.app/Contents/Helpers/tilde`.
- [ ] `packaging/installer/README.md` — guided Packages.app checklist
      (payload, symlink, preinstall script, Developer ID Installer signing).
- [ ] `.pkgproj` created by hand in Packages.app (owner's own work, guided —
      not authored by the agent). `Tilde/Tilde.pkgproj` already exists as a
      work-in-progress start.
- [ ] Xcode packaging scheme/Run Script wired to invoke `packagesbuild`
      against the finished `.pkgproj`.
- [ ] Verified: installer doesn't clobber a foreign existing
      `/usr/local/bin/tilde`; installed app + symlink both work.

## Final verification (once A–G are done)

- [ ] Move the built `Tilde.app` outside the repo and outside `$PATH`'s
      Homebrew dirs; `Contents/Helpers/tilde <file>` works with no env
      assistance.
- [ ] `codesign --verify --deep --strict --verbose=2 Tilde.app` and
      `spctl -a -vv Tilde.app` both pass.
- [ ] `tilde somefile` from an already-open terminal runs the editor
      directly — never opens the chooser or another terminal window.
