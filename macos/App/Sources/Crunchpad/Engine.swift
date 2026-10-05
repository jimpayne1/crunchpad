// SPDX-License-Identifier: GPL-2.0-or-later

import CSpeedCrunchEngine
import Foundation

struct Evaluation: Decodable, Equatable {
    enum Kind: String, Decodable {
        case value, variable, function, unit, comment, none
    }

    var ok: Bool
    var error: String?
    var kind: Kind?
    var expression: String?
    var interpreted: String?
    var simplified: String?
    var result: String?
    var bits: String?
}

struct BuiltinFunction: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var usage: String
    var domain: String
}

struct PhysicalConstant: Decodable, Identifiable, Hashable {
    var name: String
    var value: String
    var unit: String
    var domain: String
    var subdomain: String
    var id: String { domain + "/" + name }

    /// What gets inserted into the editor, matching upstream:
    /// `value[unit]` joined by a no-break space.
    var expression: String {
        unit.isEmpty ? value : value + "\u{00A0}[" + unit + "]"
    }
}

struct UserVariable: Decodable, Identifiable, Hashable {
    var id: String
    var value: String
    var description: String
}

struct UserFunction: Decodable, Identifiable, Hashable {
    var name: String
    var args: [String]
    var expression: String
    var description: String
    var id: String { name }
    var signature: String { "\(name)(\(args.joined(separator: ";")))" }
}

struct UserUnit: Decodable, Identifiable, Hashable {
    var name: String
    var expression: String
    var description: String
    var id: String { name }
}

struct Completion: Decodable, Identifiable, Hashable {
    var text: String
    var kind: String
    var detail: String
    var id: String { kind + ":" + text }
}

struct EngineSettings: Encodable {
    var angleUnit: String
    var resultFormat: String
    var precision: Int
    var complexNumbers: Bool
    var complexForm: String
    var imaginaryUnit: String
    var numberFormatStyle: Int
    var simplify: Bool
}

/// Thin Swift face over the C bridge. The engine keeps global state and is
/// not thread-safe, so everything is pinned to the main actor.
@MainActor
enum Engine {
    private static var initialized = false

    static func start() {
        guard !initialized else { return }
        sc_init()
        initialized = true
    }

    static func evaluate(_ expression: String) -> Evaluation {
        decode(sc_evaluate(expression)) ?? Evaluation(ok: false, error: "Engine error")
    }

    static func preview(_ expression: String) -> Evaluation {
        decode(sc_preview(expression)) ?? Evaluation(ok: false)
    }

    static func apply(_ settings: EngineSettings) {
        guard let data = try? JSONEncoder().encode(settings),
              let json = String(data: data, encoding: .utf8) else { return }
        sc_apply_settings(json)
    }

    static func builtinFunctions() -> [BuiltinFunction] {
        let functions: [BuiltinFunction] = decode(sc_builtin_functions()) ?? []
        return functions.map { f in
            var f = f
            f.name = f.name.plainTextFromQtRichText
            f.usage = f.usage.plainTextFromQtRichText
            return f
        }
    }
    static func constants() -> [PhysicalConstant] { decode(sc_constants()) ?? [] }
    static func userVariables() -> [UserVariable] { decode(sc_user_variables()) ?? [] }
    static func userFunctions() -> [UserFunction] { decode(sc_user_functions()) ?? [] }
    static func userUnits() -> [UserUnit] { decode(sc_user_units()) ?? [] }
    static func completions(for prefix: String) -> [Completion] { decode(sc_completions(prefix)) ?? [] }

    static func bookPage(_ id: String) -> String {
        guard let pointer = sc_book_page(id) else { return "" }
        defer { sc_free(pointer) }
        return String(cString: pointer)
    }

    static func unsetVariable(_ id: String) { sc_unset_variable(id) }
    static func unsetFunction(_ name: String) { sc_unset_function(name) }
    static func unsetUnit(_ name: String) { sc_unset_unit(name) }
    static func reset() { sc_reset() }

    private static func decode<T: Decodable>(_ pointer: UnsafeMutablePointer<CChar>?) -> T? {
        guard let pointer else { return nil }
        defer { sc_free(pointer) }
        return try? JSONDecoder().decode(T.self, from: Data(bytes: pointer, count: strlen(pointer)))
    }
}

extension String {
    /// Function usages are Qt rich text (`x<sub>1</sub>`). Subscripts become
    /// Unicode subscript characters and any other tags are dropped.
    var plainTextFromQtRichText: String {
        guard contains("<") else { return self }
        let subscripts: [Character: Character] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "n": "ₙ", "x": "ₓ",
        ]
        var text = self
        while let open = text.range(of: "<sub>"),
              let close = text.range(of: "</sub>", range: open.upperBound..<text.endIndex) {
            let inner = text[open.upperBound..<close.lowerBound]
            text.replaceSubrange(open.lowerBound..<close.upperBound,
                                 with: String(inner.map { subscripts[$0] ?? $0 }))
        }
        return text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Engine messages carry `<b>…</b>` markup meant for Qt rich text.
    var engineMarkupAsAttributed: AttributedString {
        let markdown = replacingOccurrences(of: "<b>", with: "**")
            .replacingOccurrences(of: "</b>", with: "**")
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(self)
    }
}
