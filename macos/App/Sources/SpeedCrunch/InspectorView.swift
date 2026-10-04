// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

struct InspectorView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case defined = "Defined", functions = "Functions", constants = "Constants"
        var id: String { rawValue }
    }

    @SceneStorage("inspectorTab") private var tab: Tab = .defined
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 10)

            TextField("Filter", text: $search, prompt: Text("Filter"))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            switch tab {
            case .defined: DefinedList(search: search)
            case .functions: FunctionList(search: search)
            case .constants: ConstantList(search: search)
            }
        }
    }
}

private func matches(_ search: String, _ fields: String...) -> Bool {
    search.isEmpty || fields.contains { $0.localizedCaseInsensitiveContains(search) }
}

private struct DefinedList: View {
    @Environment(Calculator.self) private var calculator
    let search: String

    var body: some View {
        let variables = calculator.variables.filter { matches(search, $0.id, $0.description) }
        let functions = calculator.userFunctions.filter { matches(search, $0.name, $0.expression) }
        let units = calculator.userUnits.filter { matches(search, $0.name, $0.expression) }

        if variables.isEmpty && functions.isEmpty && units.isEmpty {
            ContentUnavailableView("Nothing Defined",
                                   systemImage: "x.squareroot",
                                   description: Text("Assign with x = 42, define functions with f(x) = x^2."))
                .frame(maxHeight: .infinity)
        } else {
            List {
                if !variables.isEmpty {
                    Section("Variables") {
                        ForEach(variables) { v in
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
                    }
                }
                if !functions.isEmpty {
                    Section("Functions") {
                        ForEach(functions) { f in
                            SymbolRow(title: f.signature, detail: f.expression, note: f.description)
                                .onTapGesture(count: 2) { calculator.insertFunction(f.name) }
                                .contextMenu {
                                    Button("Insert") { calculator.insertFunction(f.name) }
                                    Divider()
                                    Button("Delete", role: .destructive) { calculator.deleteFunction(f.name) }
                                }
                        }
                    }
                }
                if !units.isEmpty {
                    Section("Units") {
                        ForEach(units) { u in
                            SymbolRow(title: u.name, detail: u.expression, note: u.description)
                                .onTapGesture(count: 2) { calculator.insert("[\(u.name)]") }
                                .contextMenu {
                                    Button("Insert") { calculator.insert("[\(u.name)]") }
                                    Divider()
                                    Button("Delete", role: .destructive) { calculator.deleteUnit(u.name) }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

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
                            .onTapGesture(count: 2) { calculator.insert(insertion(for: c)) }
                            .help("Double-click to insert")
                            .contextMenu {
                                Button("Insert") { calculator.insert(insertion(for: c)) }
                                Button("Copy Value") { calculator.copy(c.value) }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func insertion(for constant: PhysicalConstant) -> String {
        constant.unit.isEmpty ? constant.value : "(\(constant.value) \(constant.unit))"
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
            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !note.isEmpty {
                Text(note).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
