// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct SettingsView: View {
    @Environment(Calculator.self) private var calculator
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some View {
        @Bindable var calculator = calculator

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $calculator.appearance) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Results") {
                Picker("Format", selection: $calculator.resultFormat) {
                    ForEach(ResultFormat.allCases) { Text($0.label).tag($0) }
                }
                Picker("Precision", selection: $calculator.precision) {
                    Text("Automatic").tag(-1)
                    ForEach([0, 2, 4, 8, 12, 16, 20, 30, 50], id: \.self) { Text("\($0) digits").tag($0) }
                }
                Picker("Number style", selection: $calculator.numberStyle) {
                    ForEach(NumberStyle.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Simplify displayed expressions", isOn: $calculator.simplifyExpressions)
            }

            Section("Angles & Complex Numbers") {
                Picker("Angle unit", selection: $calculator.angleUnit) {
                    ForEach(AngleUnit.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Complex numbers", isOn: $calculator.complexNumbers)
                Picker("Complex form", selection: $calculator.complexForm) {
                    ForEach(ComplexForm.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!calculator.complexNumbers)
                Picker("Imaginary unit", selection: $calculator.imaginaryUnitJ) {
                    Text("i").tag(false)
                    Text("j").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(!calculator.complexNumbers)
            }

            Section("Behavior") {
                Toggle("Operator at start continues from last result (auto ans)", isOn: $calculator.autoAns)
                Toggle("Copy each result to the clipboard", isOn: $calculator.autoCopyResult)
                Toggle("Keep expression after evaluating", isOn: $calculator.keepLastExpression)
                Toggle("Show in menu bar", isOn: $showMenuBarExtra)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Compact calculator for the menu bar extra. Shares state with the window.
struct QuickCalculatorView: View {
    @Environment(Calculator.self) private var calculator
    @Environment(\.openWindow) private var openWindow
    @FocusState private var focus: FocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(calculator.history.suffix(6)) { entry in
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(entry.expression)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if let result = entry.result {
                                Text(result)
                                    .font(.system(.title3, design: .monospaced))
                                    .textSelection(.enabled)
                                    .onTapGesture { calculator.copy(result) }
                                    .help("Click to copy")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(12)
            }
            .defaultScrollAnchor(.bottom)
            .frame(height: 170)

            Divider()
            InputBar(focus: $focus, fontSize: 16)
                .onAppear { focus = .editor }
            Divider()
            HStack {
                Text(calculator.angleUnit.short)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open SpeedCrunch") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}
