// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct KeypadView: View {
    @Environment(Calculator.self) private var calculator

    private enum Key: Hashable {
        case text(String, insert: String? = nil)
        case function(String, label: String? = nil)
        case backspace, clear, evaluate
    }

    private let scientific: [[Key]] = [
        [.function("sin"), .function("cos"), .function("tan"), .function("ln"), .function("log10", label: "log")],
        [.function("arcsin", label: "sin⁻¹"), .function("arccos", label: "cos⁻¹"), .function("arctan", label: "tan⁻¹"),
         .function("exp", label: "eˣ"), .function("sqrt", label: "√")],
        [.text("π", insert: "pi"), .text("e"), .text("xʸ", insert: "^"), .text("x²", insert: "^2"), .text("n!", insert: "!")],
        [.text("("), .text(")"), .text("ans"), .text("x", insert: "x"), .text("=")],
    ]

    private let basic: [[Key]] = [
        [.text("7"), .text("8"), .text("9"), .text("÷", insert: "/"), .clear],
        [.text("4"), .text("5"), .text("6"), .text("×", insert: "*"), .backspace],
        [.text("1"), .text("2"), .text("3"), .text("−", insert: "-"), .text("%")],
        [.text("0"), .text("."), .text(";"), .text("+"), .evaluate],
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            grid(scientific, secondary: true)
            grid(basic, secondary: false)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
    }

    private func grid(_ rows: [[Key]], secondary: Bool) -> some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r], id: \.self) { key in
                        button(for: key, secondary: secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func button(for key: Key, secondary: Bool) -> some View {
        switch key {
        case let .text(label, insert):
            KeyButton(label: label, style: secondary ? .secondary : .digit) { calculator.insert(insert ?? label) }
        case let .function(name, label):
            KeyButton(label: label ?? name, style: .secondary) { calculator.insertFunction(name) }
        case .backspace:
            KeyButton(label: "⌫", style: .secondary) { calculator.backspace() }
        case .clear:
            KeyButton(label: "C", style: .secondary) { calculator.clearInput() }
        case .evaluate:
            KeyButton(label: "=", style: .accent) { calculator.commit() }
        }
    }
}

private struct KeyButton: View {
    enum Style { case digit, secondary, accent }
    let label: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: style == .digit ? .medium : .regular, design: .rounded))
                .frame(width: 52, height: 30)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .foregroundStyle(style == .accent ? Color.white : Color.primary)
    }

    private var tint: Color {
        switch style {
        case .digit: Color.primary.opacity(0.10)
        case .secondary: Color.primary.opacity(0.05)
        case .accent: .accentColor
        }
    }
}
