// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct ContentView: View {
    @Environment(Calculator.self) private var calculator
    @FocusState private var focus: FocusField?

    var body: some View {
        @Bindable var calculator = calculator

        VStack(spacing: 0) {
            TranscriptView()
            Divider()
            InputBar(focus: $focus)
            if calculator.showStatusBar {
                Divider()
                StatusBar()
            }
        }
        .background(.background)
        .inspector(isPresented: $calculator.showInspector) {
            InspectorView(focus: $focus)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 460)
        }
        .navigationTitle("SpeedCrunch")
        .navigationSubtitle("\(calculator.angleUnit.label) · \(calculator.resultFormat.label)")
        .onAppear { focus = .editor }
        .onChange(of: calculator.focusRequest) { focus = .editor }
        .onChange(of: calculator.focusCycleRequest) {
            // Two stops (editor, inspector), so forward and backward coincide.
            focus = (focus == .editor && calculator.showInspector) ? .inspectorFilter : .editor
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                AngleMenu()
                FormatMenu()

                Button {
                    calculator.clearHistory()
                } label: {
                    Label("Clear History", systemImage: "eraser")
                }
                .help("Clear history (⌘K)")
                .disabled(calculator.history.isEmpty)

                Button {
                    calculator.showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Functions, constants, variables… (⌘1–⌘8)")
            }
        }
    }
}

private struct AngleMenu: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        @Bindable var calculator = calculator
        Menu {
            Picker("Angle Unit", selection: $calculator.angleUnit) {
                ForEach(AngleUnit.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Text(calculator.angleUnit.short)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
        }
        .help("Angle unit (⌥⌘R radians, ⌥⌘D degrees)")
    }
}

private struct FormatMenu: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        @Bindable var calculator = calculator
        Menu {
            Picker("Result Format", selection: $calculator.resultFormat) {
                ForEach(ResultFormat.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
            PrecisionPicker()
        } label: {
            Label("Format", systemImage: "number")
        }
        .help("Result format (F2–F10) and precision")
    }
}

private struct PrecisionPicker: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        @Bindable var calculator = calculator
        Picker("Precision", selection: $calculator.precision) {
            Text("Automatic").tag(-1)
            ForEach([2, 4, 8, 12, 16, 20, 30, 50], id: \.self) { Text("\($0) digits").tag($0) }
        }
    }
}

/// Upstream's optional status bar (⌘B): quick angle/notation/precision selectors.
private struct StatusBar: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        @Bindable var calculator = calculator
        HStack(spacing: 14) {
            Picker("Angle", selection: $calculator.angleUnit) {
                ForEach(AngleUnit.allCases) { Text($0.label).tag($0) }
            }
            Picker("Notation", selection: $calculator.resultFormat) {
                ForEach(ResultFormat.allCases) { Text($0.label).tag($0) }
            }
            PrecisionPicker()
            Spacer()
        }
        .pickerStyle(.menu)
        .buttonStyle(.borderless)
        .controlSize(.small)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Transcript

struct TranscriptView: View {
    @Environment(Calculator.self) private var calculator
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var geometry = ScrollGeometry?.none

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(calculator.history) { entry in
                    EntryRow(entry: entry)
                    Divider().opacity(0.4)
                }
            }
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom)
        .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, new in geometry = new }
        .overlay {
            if calculator.history.isEmpty { EmptyTranscript() }
        }
        .onChange(of: calculator.history.count) {
            withAnimation(.snappy) { position.scrollTo(edge: .bottom) }
        }
        .onChange(of: calculator.scrollRequest?.serial) {
            guard let command = calculator.scrollRequest?.command else { return }
            perform(command)
        }
    }

    /// Page Up/Down (page-wise), ⇧ (line-wise), ⌘ (top/bottom), as upstream.
    private func perform(_ command: ScrollCommand) {
        guard let g = geometry else { return }
        let page = max(40, g.visibleRect.height - 40)
        let line = calculator.displayFontSize * 2.2
        let maxY = max(0, g.contentSize.height - g.containerSize.height)
        let y: CGFloat
        switch command {
        case .top: withAnimation(.snappy) { position.scrollTo(edge: .top) }; return
        case .bottom: withAnimation(.snappy) { position.scrollTo(edge: .bottom) }; return
        case .pageUp: y = g.contentOffset.y - page
        case .pageDown: y = g.contentOffset.y + page
        case .lineUp: y = g.contentOffset.y - line
        case .lineDown: y = g.contentOffset.y + line
        }
        withAnimation(.snappy(duration: 0.15)) { position.scrollTo(y: min(maxY, max(0, y))) }
    }
}

private struct EmptyTranscript: View {
    var body: some View {
        ContentUnavailableView {
            Label("SpeedCrunch", systemImage: "function")
        } description: {
            VStack(spacing: 6) {
                Text("High-precision calculator. Try:")
                Group {
                    Text("sqrt(2) * pi")
                    Text("x = 3; f(t) = t^2 + 1")
                    Text("10[metre] -> [foot]")
                    Text("(1+2i)·(3−i)")
                    Text("0xFF + 0b1010")
                }
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct EntryRow: View {
    @Environment(Calculator.self) private var calculator
    let entry: HistoryEntry
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.interpreted.isEmpty ? entry.expression : entry.interpreted)
                    .font(.system(size: calculator.displayFontSize * 0.68, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .onTapGesture(count: 2) { calculator.use(entry) }
                    .help("Double-click to recall this expression")

                if let result = entry.result {
                    Text("= \(result)")
                        .font(.system(size: calculator.displayFontSize, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .onTapGesture(count: 2) { calculator.insert(result) }
                        .help("Double-click to insert into the expression")
                } else {
                    Text(label(for: entry.kind))
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

            }
            Spacer(minLength: 0)
            if hovering {
                HStack(spacing: 2) {
                    if let result = entry.result {
                        IconButton("doc.on.doc", help: "Copy result") { calculator.copy(result) }
                    }
                    IconButton("arrow.uturn.down", help: "Edit expression") { calculator.use(entry) }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(hovering ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu {
            if let result = entry.result {
                Button("Copy Result") { calculator.copy(result) }
                Button("Insert Result") { calculator.insert(result) }
            }
            Button("Copy Expression") { calculator.copy(entry.expression) }
            Button("Edit Expression") { calculator.use(entry) }
            Divider()
            Button("Delete", role: .destructive) { calculator.remove(entry) }
        }
    }

    private func label(for kind: String) -> String {
        switch kind {
        case "function": "function defined"
        case "unit": "unit defined"
        default: ""
        }
    }
}

struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    init(_ systemImage: String, help: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
