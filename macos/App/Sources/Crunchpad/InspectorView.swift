// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import WebKit

struct InspectorView: View {
    @Environment(Calculator.self) private var calculator
    var focus: FocusState<FocusField?>.Binding
    @State private var search = ""

    var body: some View {
        @Bindable var calculator = calculator
        let panel = calculator.inspectorPanel

        VStack(spacing: 0) {
            Picker("Panel", selection: $calculator.inspectorPanel) {
                ForEach(InspectorPanel.allCases) { p in
                    Image(systemName: p.systemImage)
                        .help("\(p.title) (⌘\(p.rawValue))")
                        .tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Text(panel.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 8)

            TextField("Filter", text: $search, prompt: Text("Filter"))
                .textFieldStyle(.roundedBorder)
                .focused(focus, equals: .inspectorFilter)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .opacity(panel == .book || panel == .bitField ? 0 : 1)
                .frame(height: panel == .book || panel == .bitField ? 8 : nil)

            Group {
                switch panel {
                case .book: FormulaBookView()
                case .constants: ConstantList(search: search)
                case .functions: FunctionList(search: search)
                case .variables: VariableList(search: search)
                case .userFunctions: UserFunctionList(search: search)
                case .userUnits: UserUnitList(search: search)
                case .history: HistoryList(search: search)
                case .bitField: BitFieldView()
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private func matches(_ search: String, _ fields: String...) -> Bool {
    search.isEmpty || fields.contains { $0.localizedCaseInsensitiveContains(search) }
}

// MARK: - Built-ins

private struct FunctionList: View {
    @Environment(Calculator.self) private var calculator
    let search: String

    var body: some View {
        let filtered = calculator.builtinFunctions.filter { matches(search, $0.id, $0.name, $0.domain) }
        let domains = Dictionary(grouping: filtered, by: \.domain)
        List {
            ForEach(domains.keys.sorted(), id: \.self) { domain in
                Section(domain.isEmpty ? "Other" : domain) {
                    ForEach(domains[domain] ?? []) { f in
                        SymbolRow(title: "\(f.id)(\(f.usage))", detail: f.name, note: "")
                            .onTapGesture(count: 2) { calculator.insertFunction(f.id) }
                            .help("Double-click to insert")
                            .contextMenu {
                                Button("Insert") { calculator.insertFunction(f.id) }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct ConstantList: View {
    @Environment(Calculator.self) private var calculator
    let search: String

    var body: some View {
        let filtered = calculator.constants.filter { matches(search, $0.name, $0.domain, $0.subdomain) }
        let domains = Dictionary(grouping: filtered, by: \.domain)
        List {
            ForEach(domains.keys.sorted(), id: \.self) { domain in
                Section(domain.isEmpty ? "Other" : domain) {
                    ForEach(domains[domain] ?? []) { c in
                        SymbolRow(title: c.name,
                                  detail: c.unit.isEmpty ? c.value : "\(c.value) \(c.unit)",
                                  note: c.subdomain)
                            .onTapGesture(count: 2) { calculator.insert(c.expression) }
                            .help("Double-click to insert")
                            .contextMenu {
                                Button("Insert") { calculator.insert(c.expression) }
                                Button("Copy Value") { calculator.copy(c.value) }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - User definitions (Delete key removes the selection, as upstream)

private struct VariableList: View {
    @Environment(Calculator.self) private var calculator
    let search: String
    @State private var selection: String?

    var body: some View {
        let items = calculator.variables.filter { matches(search, $0.id, $0.description) }
        if items.isEmpty {
            EmptyPanel("No Variables", "Assign one with x = 42.")
        } else {
            List(items, selection: $selection) { v in
                SymbolRow(title: v.id, detail: v.value, note: v.description)
                    .onTapGesture(count: 2) { calculator.insert(v.id) }
                    .contextMenu {
                        Button("Insert") { calculator.insert(v.id) }
                        Button("Copy Value") { calculator.copy(v.value) }
                        if v.id != "ans" {
                            Divider()
                            Button("Delete", role: .destructive) { calculator.deleteVariable(v.id) }
                        }
                    }
            }
            .listStyle(.sidebar)
            .onDeleteCommand {
                if let id = selection, id != "ans" { calculator.deleteVariable(id) }
            }
        }
    }
}

private struct UserFunctionList: View {
    @Environment(Calculator.self) private var calculator
    let search: String
    @State private var selection: String?

    var body: some View {
        let items = calculator.userFunctions.filter { matches(search, $0.name, $0.expression) }
        if items.isEmpty {
            EmptyPanel("No User Functions", "Define one with f(x) = x^2 + 1.")
        } else {
            List(items, selection: $selection) { f in
                SymbolRow(title: f.signature, detail: f.expression, note: f.description)
                    .onTapGesture(count: 2) { calculator.insertFunction(f.name) }
                    .contextMenu {
                        Button("Insert") { calculator.insertFunction(f.name) }
                        Divider()
                        Button("Delete", role: .destructive) { calculator.deleteFunction(f.name) }
                    }
            }
            .listStyle(.sidebar)
            .onDeleteCommand {
                if let name = selection { calculator.deleteFunction(name) }
            }
        }
    }
}

private struct UserUnitList: View {
    @Environment(Calculator.self) private var calculator
    let search: String
    @State private var selection: String?

    var body: some View {
        let items = calculator.userUnits.filter { matches(search, $0.name, $0.expression) }
        if items.isEmpty {
            EmptyPanel("No User Units", "Define one with furlong = 201.168[metre].")
        } else {
            List(items, selection: $selection) { u in
                SymbolRow(title: u.name, detail: u.expression, note: u.description)
                    .onTapGesture(count: 2) { calculator.insert("[\(u.name)]") }
                    .contextMenu {
                        Button("Insert") { calculator.insert("[\(u.name)]") }
                        Divider()
                        Button("Delete", role: .destructive) { calculator.deleteUnit(u.name) }
                    }
            }
            .listStyle(.sidebar)
            .onDeleteCommand {
                if let name = selection { calculator.deleteUnit(name) }
            }
        }
    }
}

private struct HistoryList: View {
    @Environment(Calculator.self) private var calculator
    let search: String

    var body: some View {
        let items = calculator.history.reversed().filter { matches(search, $0.expression, $0.result ?? "") }
        if items.isEmpty {
            EmptyPanel("No History", "Evaluated expressions appear here.")
        } else {
            List(items) { entry in
                SymbolRow(title: entry.expression, detail: entry.result.map { "= \($0)" } ?? "", note: "")
                    .onTapGesture(count: 2) { calculator.use(entry) }
                    .help("Double-click to recall")
                    .contextMenu {
                        Button("Recall Expression") { calculator.use(entry) }
                        if let r = entry.result { Button("Insert Result") { calculator.insert(r) } }
                    }
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Bit field (⌘8)

private struct BitFieldView: View {
    @Environment(Calculator.self) private var calculator

    var body: some View {
        let value = calculator.bitValue
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 6) {
                ForEach(0..<4) { row in
                    let high = 63 - row * 16
                    HStack(spacing: 0) {
                        Text("\(high)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, alignment: .trailing)
                            .padding(.trailing, 4)
                        ForEach(0..<16) { col in
                            let bit = high - col
                            BitCell(on: value & (1 << UInt64(bit)) != 0) {
                                calculator.setBits(value ^ (1 << UInt64(bit)))
                            }
                            .help("Bit \(bit)")
                            if col % 4 == 3 && col != 15 { Spacer().frame(width: 5) }
                        }
                    }
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                GridRow { Text("DEC").foregroundStyle(.secondary); Text(String(value)) }
                GridRow { Text("HEX").foregroundStyle(.secondary); Text("0x" + String(value, radix: 16, uppercase: true)) }
            }
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)

            HStack {
                Button("Clear") { calculator.setBits(0) }
                Button("Invert") { calculator.setBits(~value) }
                Button("«") { calculator.setBits(value << 1) }.help("Shift left")
                Button("»") { calculator.setBits(value >> 1) }.help("Shift right")
            }
            .controlSize(.small)

            Text("Follows the last integer result. Click bits to edit; the value goes into the expression as hex.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

private struct BitCell: View {
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .frame(width: 13, height: 18)
                .overlay(Text(on ? "1" : "0").font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(on ? .white : .secondary))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 0.5)
    }
}

// MARK: - Formula book (⌘1)

private struct FormulaBookView: View {
    @Environment(Calculator.self) private var calculator
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BookWebView(dark: colorScheme == .dark) { formula in
            calculator.setInput(formula)
            calculator.requestFocus()
        }
    }
}

/// Renders upstream's formula book pages. Page links navigate within the
/// book; `formula:` links put the formula into the editor.
private struct BookWebView: NSViewRepresentable {
    let dark: Bool
    let onFormula: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFormula: onFormula) }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        context.coordinator.dark = dark
        context.coordinator.load("index")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onFormula = onFormula
        if context.coordinator.dark != dark {
            context.coordinator.dark = dark
            context.coordinator.load(context.coordinator.page)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var onFormula: (String) -> Void
        var dark = true
        var page = "index"
        static let base = URL(string: "book:///")!

        init(onFormula: @escaping (String) -> Void) { self.onFormula = onFormula }

        func load(_ id: String) {
            page = id
            let fg = dark ? "#e8e8e8" : "#1d1d1f"
            let link = dark ? "#8ab4f8" : "#0a66c2"
            let theme = """
            <style>
            body { background: transparent !important; color: \(fg) !important;
                   font: 13px -apple-system, sans-serif; margin: 4px 14px; }
            h1 { font-size: 17px; } h2, h3 { font-size: 14px; font-family: -apple-system, sans-serif; }
            .page-link a:link, .page-link a:visited { color: \(link) !important; font-family: -apple-system, sans-serif; }
            .formula a:link, .formula a:visited { color: \(link) !important; font-size: 14px; }
            .caption, .variable { color: \(fg) !important; opacity: .8; }
            </style></head>
            """
            let html = Engine.bookPage(id).replacingOccurrences(of: "</head>", with: theme)
            webView?.loadHTMLString(html, baseURL: Self.base)
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard action.navigationType == .linkActivated, let url = action.request.url else { return .allow }
            if url.scheme == "formula" {
                let raw = url.absoluteString.dropFirst("formula:".count)
                onFormula(String(raw).removingPercentEncoding ?? String(raw))
            } else {
                load(String(url.path.drop { $0 == "/" }))
            }
            return .cancel
        }
    }
}

// MARK: - Shared rows

private struct EmptyPanel: View {
    let title: String
    let hint: String
    init(_ title: String, _ hint: String) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        ContentUnavailableView(title, systemImage: "tray", description: Text(hint))
    }
}

private struct SymbolRow: View {
    let title: String
    let detail: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !note.isEmpty {
                Text(note).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
