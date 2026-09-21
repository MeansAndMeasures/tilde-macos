# `packaging/embed-frameworks.sh` — spec

Workstream B. This document is the exact spec; **the script itself is
written by hand in Xcode/your editor, not by the agent** — same "I spec it,
you type it" split as the rest of the signing-adjacent work. Everything
below is grounded in actually running `otool -l`/`otool -L` against a real
`meson compile -C build-release tilde` output and reading
`build-release/meson-info/intro-install_plan.json`, not assumed.

## What this script is for

Xcode's Copy Files phases can drop files into `Contents/Frameworks`, but
they can't rewrite Mach-O load commands or re-sign. Everything currently
built by Meson references either the **build tree** (`@loader_path/../t3widget`,
relative to where `tilde` sits *inside* `build-release/meson/tilde/`) or an
**absolute Homebrew path** (`/opt/homebrew/opt/...`). Neither survives being
copied into the app bundle. This script runs as an early Run Script build
phase, after Workstream C's Meson install step has produced a staging tree
and before Xcode's own bundle-signing pass, and turns that staging tree's
binaries into ones that resolve entirely relative to `Contents/Frameworks`.

## Inputs

- A staging root (Meson `DESTDIR`-style install tree) as `$1`, or an env var
  — whatever Workstream C's Run Script phase ends up exporting; don't
  hardcode a path. Below, this is called `$STAGE`.
- `$TARGET_BUILD_DIR` and `$CONTENTS_FOLDER_PATH` (standard Xcode build
  phase env vars) — `"$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"` is the
  absolute path to `Contents/` inside the app bundle being built. Below,
  this is called `$CONTENTS`.
- `$EXPANDED_CODE_SIGN_IDENTITY` (standard Xcode build phase env var) — pass
  directly to `codesign -s`.

## Exact current-state findings (from `otool` on `build-release/meson`)

Confirmed by running `otool -L` and `otool -l | grep -A2 LC_RPATH` against
every target in a real `build-release` output.

**Install-name/load-command state — already clean, no action needed:** every
one of the 6 component dylibs already has its own id as `@rpath/lib<name>.dylib`
(`otool -D`), and every `@rpath/...` cross-dependency between them
(`tilde` → `t3widget`/`t3window`/`transcript`/`t3config`/`t3highlight`;
`t3widget` → `t3window`/`transcript`/`t3key`/`t3config`; `t3highlight` →
`t3config`; `t3key` → `t3config`; `t3window` → `transcript`) is already
`@rpath`-relative. The 24 `.ltc` modules only depend on
`@rpath/libtranscript.dylib` + system libs — already clean too. **None of
these need `install_name_tool -change`.**

**3 absolute Homebrew leaf libraries, referenced by 4 different dylibs —
these do need fixing:**

| Absolute path currently loaded | Referenced by (via `otool -L`) |
|---|---|
| `/opt/homebrew/opt/libunistring/lib/libunistring.5.dylib` | `tilde`, `libt3widget.dylib`, `libt3window.dylib` |
| `/opt/homebrew/opt/gettext/lib/libintl.8.dylib` | `libt3config.dylib`, `libt3key.dylib`, `libt3widget.dylib`, `libt3window.dylib` |
| `/opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib` | `libt3highlight.dylib`, `libt3widget.dylib` |

`ncursesw` (`/usr/lib/libncurses.5.4.dylib`, used by `libt3key.dylib` and
`libt3window.dylib`) and everything else under `/usr/lib/` are real macOS
system libraries present on every Mac — leave those alone, never touch
`/usr/lib/*` or `/System/*` load commands.

**`LC_RPATH` entries — every one of `tilde` + the 6 dylibs carries a mix of
build-tree-relative and absolute-Homebrew rpaths that must all be replaced:**

| File | Current `LC_RPATH` entries (all to be deleted) |
|---|---|
| `tilde` | `@loader_path/../{t3widget,t3window,transcript,t3key,t3config,t3highlight}` (6), `/opt/homebrew/opt/libunistring/lib`, `/opt/homebrew/opt/gettext/lib`, `/opt/homebrew/Cellar/pcre2/10.48/lib` |
| `libt3config.dylib` | `/opt/homebrew/opt/gettext/lib` |
| `libt3highlight.dylib` | `@loader_path/../t3config`, `/opt/homebrew/opt/gettext/lib`, `/opt/homebrew/Cellar/pcre2/10.48/lib` |
| `libt3key.dylib` | `@loader_path/../t3config`, `/opt/homebrew/opt/gettext/lib` |
| `libt3widget.dylib` | `@loader_path/../{t3window,transcript,t3key,t3config}`, `/opt/homebrew/opt/libunistring/lib`, `/opt/homebrew/opt/gettext/lib`, `/opt/homebrew/Cellar/pcre2/10.48/lib` |
| `libt3window.dylib` | `@loader_path/../transcript`, `/opt/homebrew/opt/libunistring/lib`, `/opt/homebrew/opt/gettext/lib` |
| `libtranscript.dylib` | *(none)* |

(Note the pcre2 rpath uses the versioned `Cellar/pcre2/10.48` path rather
than the `opt/pcre2` symlink Meson uses for the actual load command — an
existing inconsistency in what Meson emits, irrelevant here since every one
of these entries gets deleted, not edited.)

## Target end-state

Final bundle layout is flat: `tilde` lives at `Contents/Helpers/tilde`; all
6 component dylibs + the 3 re-homed Homebrew leaf libs live together,
unnested, directly in `Contents/Frameworks/`; the `.ltc` modules +
`aliases.txt` live in `Contents/Frameworks/transcript/` (one level below
the dylibs — see the Workstream A commit message for why `aliases.txt` has
to sit there and not under `Resources/`).

Because everything ends up flat like that, **the correct replacement rpath
differs by where the file itself ends up**, not one value for everything:

- `Contents/Helpers/tilde` → add exactly one rpath: `@loader_path/../../Frameworks`
- each of the 6 dylibs, now living directly in `Contents/Frameworks/` →
  add exactly one rpath: `@loader_path` (siblings are right there, no `..`
  needed)
- the `.ltc` modules, in `Contents/Frameworks/transcript/` → add exactly
  one rpath: `@loader_path/..` (their one dependency, `libtranscript.dylib`,
  is one directory up)

## Procedure

Written as the sequence of operations, not literal script text — translate
this into `packaging/embed-frameworks.sh` yourself.

1. **Copy** `$STAGE/bin/tilde` → `$CONTENTS/Helpers/tilde`.
2. **Copy** the 6 `$STAGE/lib/lib*.dylib` → `$CONTENTS/Frameworks/`.
3. **Copy** `$STAGE/lib/transcript/` (the `.ltc` modules + `aliases.txt`) →
   `$CONTENTS/Frameworks/transcript/`.
4. **Resolve and copy** the 3 Homebrew leaf libs into `$CONTENTS/Frameworks/`:
   for each of `libunistring`, `gettext`, `pcre2`, run `brew --prefix <formula>`
   and copy the real (non-symlink) dylib file from `<prefix>/lib/` —
   e.g. `$(brew --prefix libunistring)/lib/libunistring.5.dylib`. Copy the
   actual file, not the unversioned `.dylib` symlink Homebrew also provides;
   the load commands above reference the versioned name.
5. For each of the 3 copied leaf libs: `install_name_tool -id @rpath/<filename> <copied path>`
   (e.g. `install_name_tool -id @rpath/libunistring.5.dylib .../Frameworks/libunistring.5.dylib`).
6. For every Mach-O file that references one of the 3 absolute paths (per
   the table above — `tilde` and the specific dylibs listed, now at their
   *copied* bundle locations): `install_name_tool -change /opt/homebrew/... @rpath/<filename> <copied path>`,
   one `-change` per absolute reference that file actually has (don't run
   `-change` for a library a file doesn't depend on — `otool -L` on the
   *copied* file first if you want to drive this programmatically rather
   than off the static table above).
7. For every one of `tilde` + the 6 dylibs + every `.ltc` module: delete
   **all** existing `LC_RPATH` entries (`install_name_tool -delete_rpath`,
   once per entry — `otool -l | grep -A2 LC_RPATH` on the copied file to
   enumerate them), then `-add_rpath` exactly the one correct value from
   "Target end-state" above for that file's location.
8. **Re-sign** every file this script touched — everything copied in steps
   1–4 — with `codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" <path>`.
   Must happen after every `install_name_tool` call for that file (each one
   invalidates any existing signature) and before this Run Script phase
   ends, so Xcode's own later signing pass sees already-validly-signed
   content it can re-seal rather than something broken.

## Verification (run these yourself against the script's own output)

```
otool -L "$CONTENTS/Helpers/tilde"
otool -L "$CONTENTS/Frameworks/"*.dylib
otool -l "$CONTENTS/Helpers/tilde" | grep -A2 LC_RPATH
codesign --verify --deep --strict "$CONTENTS/.."   # i.e. the .app itself
```

Expect: zero `/opt/homebrew` or `@loader_path/../<sibling>` (with a literal
sibling directory name) anywhere in any `otool -L`/`otool -l` output, and a
clean `codesign --verify`. Anything under `/usr/lib` or `/System/` in
`otool -L` output is expected and correct — leave it.
