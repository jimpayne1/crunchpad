# Crunchpad

A native macOS calculator built on the engine of
[SpeedCrunch](https://github.com/heldercorreia/speedcrunch), the high-precision
keyboard-driven calculator. Crunchpad is an independent fork and is not the
official SpeedCrunch Mac build; please report Crunchpad issues here, not upstream.

The math engine is the **unmodified upstream core** (`src/math`, `src/core`),
compiled against QtCore only, with no Qt Widgets, QtGui or QtHelp. Everything you
see is SwiftUI.

## Features

- Upstream evaluator: 50+ digit precision, complex numbers, units
  (`10[metre] -> [foot]`), user variables, functions (`f(x;y) = x*y`) and units,
  hex/oct/bin input, and the full built-in function and constant library
- Live result preview while you type, plus inline autocompletion (Tab/Return
  to accept, Esc to dismiss)
- ↑/↓ recall history; double-click a result to insert it
- Type an operator first (`+5`, `*2`) to continue from the last result (auto `ans`)
- Inspector (⌘1–⌘8): formula book, constants, functions, variables, user
  functions, user units, history and a 64-bit bit field
- Menu bar quick calculator, sharing state with the main window
- Session is restored on launch by replaying the transcript, so variables and
  functions survive restarts
- Dark by default (System/Light in Settings), native Settings window, keyboard shortcuts

Keyboard shortcuts follow upstream SpeedCrunch (Ctrl → ⌘ on macOS). On a Mac
keyboard the F-keys may need `fn` unless "Use F1, F2, etc. keys as standard
function keys" is on.

| Shortcut | Action |
| --- | --- |
| Return | Evaluate |
| ↑ / ↓ | Recall history (or move in the popup) |
| Tab / Esc | Accept / dismiss suggestion; Esc on empty popup clears the input |
| ⌘R | Copy last result |
| ⌘C / ⌘V / ⌘A | Copy / paste / select expression |
| ⌘( or ⌘) | Wrap the selection (or the whole expression) in parentheses |
| ⌃Space | Insert a physical constant |
| F1 | Help for the function under the caret |
| ⌘1 … ⌘8 | Formula book, constants, functions, variables, user functions, user units, history, bit field |
| ⌘B | Status bar |
| F2 F3 F4 F5 | General / fixed / engineering / scientific notation |
| F7 F8 F9 F10 | Octal / hexadecimal / sexagesimal / binary notation |
| Page Up / Page Down | Scroll results by page (⇧ by line, ⌘ to top/bottom) |
| ⇧↑ / ⇧↓ (or ⌘+ / ⌘−) | Larger / smaller result text |
| F6 / ⇧F6 | Move focus between editor and inspector |
| Delete | Remove the selected variable, function or unit in the inspector |
| ⌥⌘R / ⌥⌘D | Radians / degrees |
| ⌘K / ⇧⌘K | Clear history / clear history and definitions |

Not ported: upstream's multi-session tabs and panes (⌘N, ⌘O, ⌘T, ⇧⌘T,
⌘⌥←/→). This app keeps a single session.

## Installing

Download the notarized DMG from
[Releases](https://github.com/jimpayne1/crunchpad/releases), or use Homebrew:

```sh
brew install --cask jimpayne1/tap/crunchpad
```

Requires macOS 15 or later on Apple silicon.

## Building

Requires Xcode 16+ (Swift 6) and Homebrew.

```sh
brew install qtbase cmake
macos/build.sh          # -> build/Crunchpad.app
macos/build.sh --run    # build and launch
```

`build.sh` builds the engine with CMake, the app with SwiftPM, and copies
QtCore plus its dylibs (ICU, glib, …) into `Contents/Frameworks`, relinked to
`@rpath`. The result runs without Homebrew installed. It is ad-hoc signed;
for distribution, sign with a Developer ID and notarize.

### Releases

`macos/release.sh 1.0.0` builds a Developer ID-signed, notarized and stapled
`build/Crunchpad-1.0.0.dmg`; add `--publish` to tag `v1.0.0` and attach the
DMG to a GitHub release. It notarizes with Crunchpad's App Store Connect API
key (IDs built in; the `.p8` is read from `~/.appstoreconnect/private_keys/`).
To release from another Mac you need that `.p8` and the Developer ID
certificate with its private key (import the backed-up `.p12`). Releases are
Apple silicon only, because Homebrew's Qt and ICU are arm64.

For engine-only hacking, `build/engine/sccli` is a JSON REPL over the bridge
(`cmake --build build/engine --target sccli`).

## Layout

```
macos/
  Engine/
    CMakeLists.txt     static lib from upstream src/math + src/core
    settings_mac.cpp   QtCore-only replacement for src/core/settings.cpp
    bridge.cpp         extern "C" JSON API (include/SpeedCrunchEngine.h)
    cli.cpp            sccli smoke-test REPL
  App/                 SwiftPM package (SwiftUI app)
  Resources/           Info.plist, icon generator
  build.sh
```

## Tracking upstream

The fork only adds `macos/`, so upstream merges should apply cleanly:

```sh
git fetch upstream && git merge upstream/main
macos/build.sh
```

If upstream adds a new core source file or a `Settings` field, update
`Engine/CMakeLists.txt` or `Engine/settings_mac.cpp` to match.
`settings_mac.cpp` copies the constructor and the radix/grouping helpers from
`src/core/settings.cpp` verbatim.

## Copyright & License

Crunchpad © 2026 James Payne.
Based on SpeedCrunch © 2004–2026 SpeedCrunch developers.

GPL-2.0-or-later, same as SpeedCrunch (see `LICENSE`).
