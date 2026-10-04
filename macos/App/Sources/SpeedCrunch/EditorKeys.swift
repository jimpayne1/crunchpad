// SPDX-License-Identifier: GPL-2.0-or-later

import AppKit

/// Keys the expression field's NSTextView field editor consumes before
/// SwiftUI's onKeyPress sees them (arrows, Page Up/Down), plus key
/// combinations a SwiftUI menu item can't carry. Installed once as a local
/// event monitor.
@MainActor
enum EditorKeys {
    static func install() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event) ? nil : event
        }
    }

    private static func handle(_ event: NSEvent) -> Bool {
        let calculator = Calculator.shared
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

        // Upstream binds both ⌘( and ⌘) to "wrap in parentheses".
        if mods == .command, event.charactersIgnoringModifiers == ")" {
            calculator.wrapInParentheses()
            return true
        }
        // ⌃Space: insert a physical constant.
        if mods == .control, event.keyCode == 49 {
            calculator.showConstantPicker()
            calculator.requestFocus()
            return true
        }

        guard editorHasFocus(event.window) else { return false }
        switch event.keyCode {
        case 126, 125: // ↑ ↓
            let up = event.keyCode == 126
            if mods == .shift {
                calculator.adjustFontSize(by: up ? 1 : -1) // upstream: ⇧↑/⇧↓
                return true
            }
            guard mods.isEmpty else { return false }
            return up ? calculator.recallPrevious() : calculator.recallNext()
        case 116, 121: // Page Up / Page Down
            let up = event.keyCode == 116
            if mods.contains(.command) || mods.contains(.control) {
                calculator.scroll(up ? .top : .bottom)
            } else if mods.contains(.shift) {
                calculator.scroll(up ? .lineUp : .lineDown)
            } else {
                calculator.scroll(up ? .pageUp : .pageDown)
            }
            return true
        default:
            return false
        }
    }

    private static func editorHasFocus(_ window: NSWindow?) -> Bool {
        guard let editor = window?.firstResponder as? NSTextView,
              let field = editor.delegate as? NSTextField else { return false }
        return field.placeholderString == InputBar.prompt
            || field.placeholderAttributedString?.string == InputBar.prompt
    }
}
