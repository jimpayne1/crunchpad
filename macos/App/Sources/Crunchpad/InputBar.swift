// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct InputBar: View {
    /// Also identifies the field to the key monitor (see EditorKeys).
    static let prompt = "Type an expression…"

    @Environment(Calculator.self) private var calculator
    var focus: FocusState<FocusField?>.Binding
    var fontSize: CGFloat = 20
    @Environment(\.controlActiveState) private var activeState

    /// The main window and the menu bar popover both show this field, bound
    /// to one selection. Only the key window's field may write it: once the
    /// popover has been opened, its hidden field otherwise reports its own
    /// stale caret on every edit and yanks the other one back (`23000` →
    /// `00032`).
    private var selection: Binding<TextSelection?> {
        Binding(
            get: { calculator.selection },
            set: { if activeState == .key { calculator.selection = $0 } })
    }

    var body: some View {
        @Bindable var calculator = calculator

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: fontSize * 0.7, weight: .semibold))
                    .foregroundStyle(.tint)
                TextField("Expression", text: $calculator.input, selection: selection,
                          prompt: Text(InputBar.prompt))
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize, design: .monospaced))
                    .autocorrectionDisabled()
                    .focused(focus, equals: .editor)
                    .onSubmit { calculator.commit(); focus.wrappedValue = .editor }
                    .onKeyPress(.tab) { calculator.acceptCompletionIfVisible() ? .handled : .ignored }
                    .onKeyPress(.escape) {
                        if calculator.helpFunction != nil {
                            calculator.helpFunction = nil
                        } else if !calculator.dismissCompletions() {
                            calculator.clearInput()
                        }
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
            Group {
                if !calculator.completions.isEmpty {
                    CompletionList()
                } else if let help = calculator.helpFunction {
                    FunctionHelp(function: help)
                }
            }
            .padding(.leading, 16 + fontSize * 0.7 + 10)
            .alignmentGuide(.top) { $0[.bottom] + 4 }
        }
        .zIndex(1)
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

private struct FunctionHelp: View {
    @Environment(Calculator.self) private var calculator
    let function: BuiltinFunction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(function.id)(\(function.usage))")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                Spacer()
                Text("esc").font(.caption2).foregroundStyle(.tertiary)
            }
            Text(function.name)
            if !function.domain.isEmpty {
                Text(function.domain).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(width: 340, alignment: .leading)
        .popupChrome()
    }
}

private struct CompletionList: View {
    @Environment(Calculator.self) private var calculator
    private let rowHeight: CGFloat = 26

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(calculator.completions.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == calculator.completionIndex)
                            .id(index)
                            .onTapGesture { calculator.accept(item) }
                    }
                }
                .padding(4)
            }
            .frame(height: min(CGFloat(calculator.completions.count), 8) * rowHeight + 8)
            .onChange(of: calculator.completionIndex) { _, index in
                proxy.scrollTo(index)
            }
        }
        .frame(width: 380, alignment: .leading)
        .popupChrome()
    }

    private func row(_ item: Completion, selected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(for: item.kind))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .frame(width: 16)
            Text(item.text)
                .font(item.kind == "physConst" ? .body : .system(.body, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 12)
            Text(item.detail)
                .font(.caption)
                .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background {
            if selected { RoundedRectangle(cornerRadius: 5).fill(.tint) }
        }
        .contentShape(Rectangle())
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "function": "function"
        case "userFunction": "f.cursive"
        case "variable": "x.squareroot"
        case "constant", "physConst": "atom"
        case "unit": "ruler"
        default: "textformat"
        }
    }
}

private extension View {
    func popupChrome() -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.separator))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}
