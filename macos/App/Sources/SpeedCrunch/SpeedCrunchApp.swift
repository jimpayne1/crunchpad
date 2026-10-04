// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

@main
struct SpeedCrunchApp: App {
    @State private var calculator = Calculator.shared
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        Window("SpeedCrunch", id: "main") {
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

        MenuBarExtra("SpeedCrunch", systemImage: "function", isInserted: $showMenuBarExtra) {
            QuickCalculatorView()
                .environment(calculator)
                .preferredColorScheme(calculator.appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}

struct CalculatorCommands: Commands {
    @Bindable var calculator: Calculator

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Last Result") { calculator.copyLastResult() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(calculator.lastResult == nil)
            Button("Insert Last Result") { calculator.insert("ans") }
                .keyboardShortcut("r", modifiers: [.command])
        }

        CommandMenu("Calculator") {
            Picker("Angle Unit", selection: $calculator.angleUnit) {
                ForEach(AngleUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }
            Picker("Result Format", selection: $calculator.resultFormat) {
                ForEach(ResultFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            Button("Use Radians") { calculator.angleUnit = .radian }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Use Degrees") { calculator.angleUnit = .degree }
                .keyboardShortcut("d", modifiers: [.command, .option])
            Divider()
            Button("Recalculate All") { calculator.recalculateAll() }
            Button("Clear History") { calculator.clearHistory() }
                .keyboardShortcut("k", modifiers: [.command])
            Button("Clear History and Definitions…") { calculator.clearAll() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
        }
    }
}
