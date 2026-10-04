// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct InputBar: View {
    @Environment(Calculator.self) private var calculator
    var fontSize: CGFloat = 20
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var calculator = calculator

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: fontSize * 0.7, weight: .semibold))
                    .foregroundStyle(.tint)
                TextField("Expression", text: $calculator.input, prompt: Text("Type an expression…"))
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize, design: .monospaced))
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit { calculator.commit(); focused = true }
                    .onKeyPress(.upArrow) { calculator.recallPrevious() ? .handled : .ignored }
                    .onKeyPress(.downArrow) { calculator.recallNext() ? .handled : .ignored }
                    .onKeyPress(.tab) { calculator.acceptCompletionIfVisible() ? .handled : .ignored }
                    .onKeyPress(.escape) {
                        if calculator.dismissCompletions() { return .handled }
                        calculator.clearInput()
                        return .handled
                    }
                if !calculator.input.isEmpty {
                    IconButton("xmark.circle.fill", help: "Clear") { calculator.clearInput() }
                        .foregroundStyle(.tertiary)
                }
            }

            StatusLine()
                .padding(.leading, fontSize * 0.7 + 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .topLeading) {
            if !calculator.completions.isEmpty {
                CompletionList()
                    .padding(.leading, 16 + fontSize * 0.7 + 10)
                    .alignmentGuide(.top) { $0[.bottom] + 4 }
            }
        }
        .zIndex(1)
        .onAppear { focused = true }
        .onChange(of: calculator.focusRequest) { focused = true }
    }
}

/// Live result preview, or the reason the last commit failed.
private struct StatusLine: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        Group {
            if let error = calculator.lastError {
                Label { Text(error.engineMarkupAsAttributed) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    .foregroundStyle(.red)
            } else if let preview = calculator.preview {
                if preview.ok, let result = preview.result {
                    Text("= \(result)")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else if let error = preview.error {
                    Text(error.engineMarkupAsAttributed)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(" ")
                }
            } else {
                Text(" ")
            }
        }
        .font(.system(.callout, design: .monospaced))
        .lineLimit(1)
        .truncationMode(.middle)
    }
}

private struct CompletionList: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(calculator.completions.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Image(systemName: icon(for: item.kind))
                        .foregroundStyle(index == calculator.completionIndex ? Color.white : Color.secondary)
                        .frame(width: 16)
                    Text(item.text)
                        .font(.system(.body, design: .monospaced))
                    Spacer(minLength: 12)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(index == calculator.completionIndex ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(index == calculator.completionIndex ? Color.white : Color.primary)
                .background {
                    if index == calculator.completionIndex {
                        RoundedRectangle(cornerRadius: 5).fill(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { calculator.accept(item) }
            }
        }
        .padding(4)
        .frame(width: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "function": "function"
        case "userFunction": "f.cursive"
        case "variable": "x.squareroot"
        case "constant": "pi"
        case "unit": "ruler"
        default: "textformat"
        }
    }
}
