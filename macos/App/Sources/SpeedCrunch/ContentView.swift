// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct ContentView: View {
    @Environment(Calculator.self) private var calculator
    @SceneStorage("showInspector") private var showInspector = true

    var body: some View {
        @Bindable var calculator = calculator

        VStack(spacing: 0) {
            TranscriptView()
            Divider()
            InputBar()
            if calculator.showKeypad {
                Divider()
                KeypadView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: calculator.showKeypad)
        .background(.background)
        .inspector(isPresented: $showInspector) {
            InspectorView()
                .inspectorColumnWidth(min: 240, ideal: 280, max: 420)
        }
        .navigationTitle("SpeedCrunch")
        .navigationSubtitle("\(calculator.angleUnit.label) · \(calculator.resultFormat.label)")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("Angle", selection: $calculator.angleUnit) {
                    ForEach([AngleUnit.radian, .degree, .gradian]) { unit in
                        Text(unit.short).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .help("Angle unit")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Result Format", selection: $calculator.resultFormat) {
                        ForEach(ResultFormat.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Picker("Precision", selection: $calculator.precision) {
                        Text("Automatic").tag(-1)
                        ForEach([2, 4, 8, 12, 16, 20, 30, 50], id: \.self) { Text("\($0) digits").tag($0) }
                    }
                } label: {
                    Label("Format", systemImage: "number")
                }
                .help("Result format and precision")

                Toggle(isOn: $calculator.showKeypad) {
                    Label("Keypad", systemImage: "circle.grid.3x3")
                }
                .help("Show keypad (⌥⌘K)")

                Button {
                    calculator.clearHistory()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .help("Clear history (⌘K)")
                .disabled(calculator.history.isEmpty)

                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show variables, functions and constants")
            }
        }
    }
}

// MARK: - Transcript

struct TranscriptView: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(calculator.history) { entry in
                        EntryRow(entry: entry)
                            .id(entry.id)
                        Divider().opacity(0.4)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .defaultScrollAnchor(.bottom)
            .overlay {
                if calculator.history.isEmpty { EmptyTranscript() }
            }
            .onChange(of: calculator.history.count) {
                withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
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

    private var alternates: [(String, String)] {
        let order = ["hex", "bin", "oct", "sci"]
        return order.compactMap { key in
            guard let value = entry.alternates[key], value != entry.result, value.count <= 72 else { return nil }
            return (key.uppercased(), value)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.interpreted.isEmpty ? entry.expression : entry.interpreted)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let result = entry.result {
                    Text("= \(result)")
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .onTapGesture(count: 2) { calculator.insert(result) }
                        .help("Double-click to insert into the expression")
                } else {
                    Text(label(for: entry.kind))
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

                if !alternates.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(alternates, id: \.0) { name, value in
                            AlternateChip(name: name, value: value)
                        }
                    }
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

private struct AlternateChip: View {
    @Environment(Calculator.self) private var calculator
    let name: String
    let value: String

    var body: some View {
        Button {
            calculator.copy(value)
        } label: {
            HStack(spacing: 4) {
                Text(name).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.system(.caption, design: .monospaced)).lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Click to copy")
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
