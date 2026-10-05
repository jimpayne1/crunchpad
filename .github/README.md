# Crunchpad

**A native Mac calculator with SpeedCrunch's high-precision engine.**

Type `sqrt(2) * pi`, `10[metre] -> [foot]`, or `f(x) = x^2 + 1` and get exact,
50+ digit answers as you type, in an app that looks and behaves like it was
made for macOS.

```sh
brew install --cask jimpayne1/tap/crunchpad
```

Or download the notarized DMG from
[Releases](https://github.com/jimpayne1/crunchpad/releases/latest).
Requires macOS 15 or later on Apple silicon.

## Why this fork exists

[SpeedCrunch](https://github.com/heldercorreia/speedcrunch) has one of the best
calculator engines around: arbitrary precision, complex numbers, units and
conversions, user-defined functions, and hundreds of built-in functions and
physical constants. It ships for macOS as a cross-platform Qt app, which works
well but doesn't feel like a Mac app.

Crunchpad keeps that engine exactly as it is and replaces everything you see
with SwiftUI:

| | SpeedCrunch (Qt) | Crunchpad |
| --- | --- | --- |
| Math engine | SpeedCrunch | **The same SpeedCrunch engine, unmodified** |
| Interface | Qt widgets and docks | SwiftUI window, inspector sidebar, Settings window |
| Appearance | Qt themes | Native light/dark (dark by default) |
| Quick access | Main window | Main window plus a menu bar calculator |
| Keyboard | SpeedCrunch shortcuts | The same shortcuts, mapped Ctrl → ⌘ |
| Install | Website download | Homebrew cask or notarized DMG |

The goal is a calculator that is as precise and keyboard-driven as SpeedCrunch,
with the polish of a native Mac app.

## Highlights

- **Answers as you type.** A live preview shows the result before you press Return.
- **Rolling calculations.** Start a line with an operator (`+5`, `*2`) to continue from the last result.
- **Autocompletion** of functions, variables, units and constants, with function help on F1.
- **Units and conversions:** `100[kilogram] * 9.81[metre/second^2]` gives `981[N]`.
- **Complex numbers, hex/oct/binary input, user variables, functions and units**, all restored on launch.
- **Inspector (⌘1–⌘8):** formula book, constants, functions, your definitions, history and a 64-bit bit field.
- **Menu bar calculator** that shares state with the main window.

See [`macos/README.md`](https://github.com/jimpayne1/crunchpad/blob/main/macos/README.md)
for the full keyboard shortcut table, build instructions and architecture.

## Staying close to upstream

Crunchpad is a fork, not a rewrite. Its own code lives in `macos/` and `.github/`,
and SpeedCrunch's code is left untouched, so upstream improvements merge in
cleanly. Bugs found in the shared engine are fixed upstream first, for example
[#1](https://github.com/heldercorreia/speedcrunch/pull/1) (`f(n) = n!` in
function definitions) and
[#2](https://github.com/heldercorreia/speedcrunch/pull/2) (constant units).

Please report Crunchpad issues [here](https://github.com/jimpayne1/crunchpad/issues)
rather than to SpeedCrunch.

## License

Crunchpad is free software under the
[GNU General Public License v2.0 or later](https://github.com/jimpayne1/crunchpad/blob/main/LICENSE),
the same license as SpeedCrunch.

Crunchpad © 2026 James Payne. Based on SpeedCrunch © 2004–2026 SpeedCrunch developers.
The rest of this repository is SpeedCrunch's source; see its
[README](https://github.com/jimpayne1/crunchpad/blob/main/README.md).
