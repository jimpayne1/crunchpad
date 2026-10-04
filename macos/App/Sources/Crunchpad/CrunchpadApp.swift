// SPDX-License-Identifier: GPL-2.0-or-later

import AppKit
import SwiftUI

@main
struct CrunchpadApp: App {
    @State private var calculator = Calculator.shared
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    init() {
        EditorKeys.install()
    }

    var body: some Scene {
        Window("Crunchpad", id: "main") {
            ContentView()
                .environment(calculator)
                .preferredColorScheme(calculator.appearance.colorScheme)
                .frame(minWidth: 460, minHeight: 360)
        }
        .defaultSize(width: 760, height: 560)
        .commands { CalculatorCommands(calculator: calculator) }

        Settings {
            SettingsView()
                .environment(calculator)
                .preferredColorScheme(calculator.appearance.colorScheme)
        }

        MenuBarExtra("Crunchpad", systemImage: "function", isInserted: $showMenuBarExtra) {
            QuickCalculatorView()
                .environment(calculator)
                .preferredColorScheme(calculator.appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}

extension KeyEquivalent {
    /// Function keys (F1…F12) as menu key equivalents.
    static func function(_ n: Int) -> KeyEquivalent {
        KeyEquivalent(Character(UnicodeScalar(UInt32(0xF703 + n))!))
    }
}

/// Keyboard shortcuts follow upstream SpeedCrunch's table, with Ctrl as ⌘
/// (as upstream does on macOS).
struct CalculatorCommands: Commands {
    @Bindable var calculator: Calculator

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Last Result") { calculator.copyLastResult() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(calculator.lastResult == nil)
            Button("Wrap in Parentheses") { calculator.wrapInParentheses() }
                .keyboardShortcut("(", modifiers: .command)
            Button("Insert Constant…") { calculator.showConstantPicker(); calculator.requestFocus() }
                .keyboardShortcut(.space, modifiers: .control)
        }

        CommandGroup(after: .sidebar) {
            ForEach(InspectorPanel.allCases) { panel in
                Toggle(panel.title, isOn: Binding(
                    get: { calculator.showInspector && calculator.inspectorPanel == panel },
                    set: { _ in calculator.togglePanel(panel) }))
                    .keyboardShortcut(panel.shortcut, modifiers: .command)
            }
            Toggle("Status Bar", isOn: $calculator.showStatusBar)
                .keyboardShortcut("b", modifiers: .command)
            Divider()
            Button("Larger Text") { calculator.adjustFontSize(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { calculator.adjustFontSize(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
            Divider()
            Button("Move Focus Forward") { calculator.cycleFocus() }
                .keyboardShortcut(.function(6), modifiers: [])
            Button("Move Focus Backward") { calculator.cycleFocus() }
                .keyboardShortcut(.function(6), modifiers: .shift)
            Divider()
        }

        CommandMenu("Calculator") {
            Section("Result Format") {
                formatToggle(.general, key: 2)
                formatToggle(.fixed, key: 3)
                formatToggle(.engineering, key: 4)
                formatToggle(.scientific, key: 5)
                formatToggle(.octal, key: 7)
                formatToggle(.hexadecimal, key: 8)
                formatToggle(.sexagesimal, key: 9)
                formatToggle(.binary, key: 10)
            }
            Divider()
            Picker("Angle Unit", selection: $calculator.angleUnit) {
                ForEach(AngleUnit.allCases) { Text($0.label).tag($0) }
            }
            Button("Use Radians") { calculator.angleUnit = .radian }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Use Degrees") { calculator.angleUnit = .degree }
                .keyboardShortcut("d", modifiers: [.command, .option])
            Divider()
            Button("Recalculate All") { calculator.recalculateAll() }
            Button("Clear History") { calculator.clearHistory() }
                .keyboardShortcut("k", modifiers: .command)
            Button("Clear History and Definitions") { calculator.clearAll() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("Function Help") { calculator.showContextHelp() }
                .keyboardShortcut(.function(1), modifiers: [])
            Divider()
            Link("SpeedCrunch Manual", destination: URL(string: "https://speedcrunch.org/userguide/")!)
            Link("Crunchpad on GitHub", destination: URL(string: "https://github.com/jimpayne1/crunchpad")!)
        }
    }

    private func formatToggle(_ format: ResultFormat, key: Int) -> some View {
        Toggle(format.label, isOn: Binding(
            get: { calculator.resultFormat == format },
            set: { _ in calculator.resultFormat = format }))
            .keyboardShortcut(.function(key), modifiers: [])
    }
}
