# SpeedCrunch for macOS

A native SwiftUI front end for [SpeedCrunch](https://github.com/heldercorreia/speedcrunch),
the high-precision keyboard-driven calculator.

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
- Inspector sidebar: your definitions, built-in functions and physical
  constants, all filterable
- Menu bar quick calculator, sharing state with the main window
- Session is restored on launch by replaying the transcript, so variables and
  functions survive restarts
- Dark by default (System/Light in Settings), native Settings window, keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘R | Insert `ans` |
| ⇧⌘C | Copy last result |
| ⌥⌘R / ⌥⌘D | Radians / degrees |
| ⌘K / ⇧⌘K | Clear history / clear history and definitions |

## Building

Requires Xcode 16+ (Swift 6) and Homebrew.

```sh
brew install qtbase cmake
macos/build.sh          # -> build/SpeedCrunch.app
macos/build.sh --run    # build and launch
```

`build.sh` builds the engine with CMake, the app with SwiftPM, and copies
QtCore plus its dylibs (ICU, glib, …) into `Contents/Frameworks`, relinked to
`@rpath`. The result runs without Homebrew installed. It is ad-hoc signed;
for distribution, sign with a Developer ID and notarize.

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

## License

GPL-2.0-or-later, same as SpeedCrunch.
