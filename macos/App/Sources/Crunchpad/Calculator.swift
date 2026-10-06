// SPDX-License-Identifier: GPL-2.0-or-later

import AppKit
import Foundation
import Observation
import SwiftUI

enum AngleUnit: String, CaseIterable, Identifiable {
    case radian = "r", degree = "d", gradian = "g", turn = "t"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .radian: "Radians"
        case .degree: "Degrees"
        case .gradian: "Gradians"
        case .turn: "Turns"
        }
    }
    var short: String {
        switch self {
        case .radian: "RAD"
        case .degree: "DEG"
        case .gradian: "GRAD"
        case .turn: "TURN"
        }
    }
}

enum ResultFormat: String, CaseIterable, Identifiable {
    case general = "g", fixed = "f", scientific = "e", engineering = "n"
    case sexagesimal = "s", hexadecimal = "h", octal = "o", binary = "b"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .general: "General"
        case .fixed: "Fixed Decimal"
        case .scientific: "Scientific"
        case .engineering: "Engineering"
        case .sexagesimal: "Sexagesimal"
        case .hexadecimal: "Hexadecimal"
        case .octal: "Octal"
        case .binary: "Binary"
        }
    }
}

enum ComplexForm: String, CaseIterable, Identifiable {
    case rectangular = "r", exponential = "e", trigonometric = "t", cis = "c", phasor = "p"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .rectangular: "Rectangular (a+bi)"
        case .exponential: "Exponential (r·e^iθ)"
        case .trigonometric: "Trigonometric"
        case .cis: "cis"
        case .phasor: "Phasor (r∠θ)"
        }
    }
}

enum NumberStyle: Int, CaseIterable, Identifiable {
    case plainDot = 1, plainComma = 2, commaDot = 5, dotComma = 7
    case spaceDot = 9, spaceComma = 10, underscoreDot = 11, indian = 15
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .plainDot: "1234567.89"
        case .plainComma: "1234567,89"
        case .commaDot: "1,234,567.89"
        case .dotComma: "1.234.567,89"
        case .spaceDot: "1 234 567.89"
        case .spaceComma: "1 234 567,89"
        case .underscoreDot: "1_234_567.89"
        case .indian: "12,34,567.89"
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case dark, system, light
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// Inspector panels, numbered like upstream's docks (⌘1…⌘8).
enum InspectorPanel: Int, CaseIterable, Identifiable {
    case book = 1, constants, functions, variables, userFunctions, userUnits, history, bitField
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .book: "Formula Book"
        case .constants: "Constants"
        case .functions: "Functions"
        case .variables: "Variables"
        case .userFunctions: "User Functions"
        case .userUnits: "User Units"
        case .history: "History"
        case .bitField: "Bit Field"
        }
    }
    var systemImage: String {
        switch self {
        case .book: "book"
        case .constants: "atom"
        case .functions: "function"
        case .variables: "x.squareroot"
        case .userFunctions: "f.cursive"
        case .userUnits: "ruler"
        case .history: "clock.arrow.circlepath"
        case .bitField: "square.grid.4x3.fill"
        }
    }
    var shortcut: KeyEquivalent { KeyEquivalent(Character(String(rawValue))) }
}

enum ScrollCommand: Equatable {
    case pageUp, pageDown, lineUp, lineDown, top, bottom
}

enum FocusField: Hashable {
    case editor, inspectorFilter
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var expression: String
    var interpreted: String
    /// Upstream's optional "= …" simplification line (empty when not useful).
    var simplified: String?
    var result: String?
    var bits: String?
    var kind: String
    var date = Date()
}

@MainActor
@Observable
final class Calculator {
    static let shared = Calculator()

    // Transcript and editor state.
    private(set) var history: [HistoryEntry] = []
    var input = "" {
        didSet {
            guard input != oldValue else { return }
            if oldValue.isEmpty, autoAns, Self.autoAnsOperators.contains(input), lastResult != nil {
                // Defer: an NSTextField mid-keystroke ignores a synchronous
                // rewrite of its binding, and the next key would clobber it.
                let op = input
                Task { @MainActor [weak self] in
                    // Fast typists may already have added more after `op`.
                    guard let self, self.input.hasPrefix(op) else { return }
                    let caret = (self.selectedRange?.upperBound ?? self.input.utf16.count) + 3
                    self.setInput("ans" + self.input, caret: caret)
                }
            }
            refreshPreview()
            refreshCompletions()
        }
    }
    private(set) var preview: Evaluation?
    private(set) var lastError: String?
    private(set) var completions: [Completion] = []
    var completionIndex = 0
    /// Typing one of these into an empty editor continues from the last
    /// result (upstream's "auto ans"), e.g. `+5` becomes `ans+5`.
    private static let autoAnsOperators: Set<String> = [
        "+", "-", "−", "*", "×", "·", "/", "÷", "^", "%", "!", "&", "|", "<", ">",
    ]
    private var recallIndex: Int?
    private var draftBeforeRecall = ""
    /// Bumped whenever the editor should take focus.
    private(set) var focusRequest = 0
    /// Bumped to move focus between editor and inspector (F6 / ⇧F6).
    private(set) var focusCycleRequest = 0
    /// Editor selection, bound to the text field (for ⌘( and F1).
    var selection: TextSelection?

    // Window chrome.
    var showInspector = false
    var inspectorPanel: InspectorPanel = .functions
    var showStatusBar: Bool { didSet { defaults.set(showStatusBar, forKey: "showStatusBar") } }
    var displayFontSize: Double { didSet { defaults.set(displayFontSize, forKey: "displayFontSize") } }
    private(set) var scrollRequest: (command: ScrollCommand, serial: Int)?
    /// Function shown by context help (F1).
    var helpFunction: BuiltinFunction?
    /// Value shown in the bit field; follows the last integer result.
    private(set) var bitValue: UInt64 = 0

    // Symbol tables surfaced in the inspector.
    private(set) var variables: [UserVariable] = []
    private(set) var userFunctions: [UserFunction] = []
    private(set) var userUnits: [UserUnit] = []
    private(set) var builtinFunctions: [BuiltinFunction] = []
    private(set) var constants: [PhysicalConstant] = []

    // Settings (persisted in UserDefaults).
    var angleUnit: AngleUnit { didSet { settingsChanged() } }
    var resultFormat: ResultFormat { didSet { settingsChanged() } }
    var precision: Int { didSet { settingsChanged() } }
    var complexNumbers: Bool { didSet { settingsChanged() } }
    var complexForm: ComplexForm { didSet { settingsChanged() } }
    var imaginaryUnitJ: Bool { didSet { settingsChanged() } }
    var numberStyle: NumberStyle { didSet { settingsChanged() } }
    var simplifyExpressions: Bool { didSet { settingsChanged() } }
    var autoCopyResult: Bool { didSet { defaults.set(autoCopyResult, forKey: "autoCopyResult") } }
    var keepLastExpression: Bool { didSet { defaults.set(keepLastExpression, forKey: "keepLastExpression") } }
    var autoAns: Bool { didSet { defaults.set(autoAns, forKey: "autoAns") } }
    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var restoring = false

    private init() {
        Self.migrateFromSpeedCrunchBuild()
        let d = UserDefaults.standard
        angleUnit = AngleUnit(rawValue: d.string(forKey: "angleUnit") ?? "") ?? .radian
        resultFormat = ResultFormat(rawValue: d.string(forKey: "resultFormat") ?? "") ?? .general
        precision = d.object(forKey: "precision") as? Int ?? -1
        complexNumbers = d.object(forKey: "complexNumbers") as? Bool ?? true
        complexForm = ComplexForm(rawValue: d.string(forKey: "complexForm") ?? "") ?? .rectangular
        imaginaryUnitJ = d.bool(forKey: "imaginaryUnitJ")
        numberStyle = NumberStyle(rawValue: d.integer(forKey: "numberStyle")) ?? .plainDot
        simplifyExpressions = d.object(forKey: "simplifyExpressions") as? Bool ?? true
        autoCopyResult = d.bool(forKey: "autoCopyResult")
        keepLastExpression = d.bool(forKey: "keepLastExpression")
        autoAns = d.object(forKey: "autoAns") as? Bool ?? true
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .dark
        showStatusBar = d.bool(forKey: "showStatusBar")
        displayFontSize = d.object(forKey: "displayFontSize") as? Double ?? 20

        Engine.start()
        applySettingsToEngine()
        builtinFunctions = Engine.builtinFunctions()
        constants = Engine.constants()
        restoreSession()
    }

    // MARK: Evaluation

    func commit() {
        if acceptCompletionIfVisible() { return }
        var expression = input.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else { return }
        // Return can beat the deferred visual rewrite in didSet.
        if autoAns, lastResult != nil, let first = expression.first,
           Self.autoAnsOperators.contains(String(first)) {
            expression = "ans" + expression
        }

        let evaluation = Engine.evaluate(expression)
        guard evaluation.ok else {
            lastError = evaluation.error ?? "Error"
            NSSound.beep()
            return
        }
        guard let kind = evaluation.kind, kind != .none else { return }

        let entry = HistoryEntry(
            expression: expression,
            interpreted: evaluation.interpreted ?? expression,
            simplified: evaluation.simplified,
            result: evaluation.result,
            bits: evaluation.bits,
            kind: kind.rawValue)
        history.append(entry)
        if entry.result != nil { bitValue = Self.bitValue(from: entry.bits) }
        helpFunction = nil
        lastError = nil
        recallIndex = nil
        refreshSymbols()
        saveSession()

        if autoCopyResult, let result = entry.result { copy(result) }
        if !keepLastExpression { setInput("") }
        preview = nil
    }

    private func refreshPreview() {
        lastError = nil
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        preview = trimmed.isEmpty ? nil : Engine.preview(trimmed)
    }

    /// Re-run the whole transcript, e.g. after the angle unit changes, so
    /// displayed results always match the current settings.
    func recalculateAll() {
        Engine.reset()
        history = history.compactMap { old in
            let e = Engine.evaluate(old.expression)
            guard e.ok, let kind = e.kind, kind != .none else { return nil }
            var entry = old
            entry.interpreted = e.interpreted ?? old.expression
            entry.simplified = e.simplified
            entry.result = e.result
            entry.bits = e.bits
            entry.kind = kind.rawValue
            return entry
        }
        refreshSymbols()
        refreshPreview()
        bitValue = Self.bitValue(from: history.last(where: { $0.result != nil })?.bits)
    }

    // MARK: Editing helpers

    /// Replaces the expression and places the caret (UTF-16 offset; default
    /// end). Every programmatic edit goes through here: a SwiftUI TextField
    /// otherwise keeps the old caret offset, e.g. `+` → `a|ns+`.
    func setInput(_ text: String, caret: Int? = nil) {
        input = text
        let offset = min(max(0, caret ?? input.utf16.count), input.utf16.count)
        selection = TextSelection(insertionPoint: String.Index(utf16Offset: offset, in: input))
    }

    /// Current selection as UTF-16 offsets, clamped to the expression.
    private var selectedRange: Range<Int>? {
        guard case let .selection(range)? = selection?.indices else { return nil }
        let count = input.utf16.count
        let lower = min(range.lowerBound.utf16Offset(in: input), count)
        let upper = min(range.upperBound.utf16Offset(in: input), count)
        return lower <= upper ? lower..<upper : nil
    }

    /// Inserts at the caret (replacing any selection), like upstream.
    func insert(_ text: String) {
        if let range = selectedRange {
            let utf16 = Array(input.utf16)
            let before = String(decoding: utf16[..<range.lowerBound], as: UTF16.self)
            let after = String(decoding: utf16[range.upperBound...], as: UTF16.self)
            setInput(before + text + after, caret: range.lowerBound + text.utf16.count)
        } else {
            setInput(input + text)
        }
        requestFocus()
    }

    func insertFunction(_ name: String) {
        insert(name + "(")
    }

    func clearInput() {
        setInput("")
        recallIndex = nil
    }

    /// ⌘( / ⌘): wrap the selection, or the whole expression, in parentheses.
    func wrapInParentheses() {
        if let range = selectedRange, !range.isEmpty {
            let utf16 = Array(input.utf16)
            let before = String(decoding: utf16[..<range.lowerBound], as: UTF16.self)
            let inner = String(decoding: utf16[range], as: UTF16.self)
            let after = String(decoding: utf16[range.upperBound...], as: UTF16.self)
            setInput(before + "(" + inner + ")" + after, caret: range.upperBound + 2)
        } else if !input.isEmpty {
            setInput("(" + input + ")")
        }
        requestFocus()
    }

    /// F1: show usage for the function under the caret, or else the
    /// innermost function call enclosing it (`sqrt(9|` → sqrt).
    func showContextHelp() {
        helpFunction = functionAtCaret
        if helpFunction == nil { NSSound.beep() }
    }

    private var functionAtCaret: BuiltinFunction? {
        var caret = input.endIndex
        if case let .selection(range)? = selection?.indices, range.upperBound <= input.endIndex {
            caret = range.lowerBound
        }
        let isIdent: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "_" }
        let lookup: (Substring) -> BuiltinFunction? = { name in
            self.builtinFunctions.first { $0.id == name }
        }
        /// Identifier ending right before `index`.
        func identifier(endingAt index: String.Index) -> Substring {
            var start = index
            while start > input.startIndex, isIdent(input[input.index(before: start)]) {
                start = input.index(before: start)
            }
            return input[start..<index]
        }

        // Word under the caret.
        var end = caret
        while end < input.endIndex, isIdent(input[end]) { end = input.index(after: end) }
        if let f = lookup(identifier(endingAt: end)) { return f }

        // Walk outwards through unmatched "(" to the enclosing calls.
        var depth = 0
        var i = caret
        while i > input.startIndex {
            i = input.index(before: i)
            switch input[i] {
            case ")": depth += 1
            case "(":
                if depth > 0 { depth -= 1; continue }
                if let f = lookup(identifier(endingAt: i)) { return f }
            default: break
            }
        }
        return nil
    }

    /// ⌃Space: pick a physical constant to insert.
    func showConstantPicker() {
        completions = constants.map {
            Completion(text: $0.name, kind: "physConst",
                       detail: $0.unit.isEmpty ? $0.value : "\($0.value) \($0.unit)")
        }
        completionIndex = 0
    }

    func togglePanel(_ panel: InspectorPanel) {
        if showInspector && inspectorPanel == panel {
            showInspector = false
            requestFocus()
        } else {
            inspectorPanel = panel
            showInspector = true
        }
    }

    func scroll(_ command: ScrollCommand) {
        scrollRequest = (command, (scrollRequest?.serial ?? 0) &+ 1)
    }

    func cycleFocus() { focusCycleRequest &+= 1 }

    func adjustFontSize(by delta: Double) {
        displayFontSize = min(48, max(11, displayFontSize + delta))
    }

    // MARK: Bit field

    private static func bitValue(from bits: String?) -> UInt64 {
        guard let bits, !bits.isEmpty else { return 0 }
        return UInt64(bits.suffix(64), radix: 2) ?? 0
    }

    /// Like upstream, editing bits writes the new value into the editor as hex.
    func setBits(_ value: UInt64) {
        bitValue = value
        setInput("0x" + String(value, radix: 16, uppercase: true))
        requestFocus()
    }

    func requestFocus() { focusRequest &+= 1 }

    func use(_ entry: HistoryEntry) {
        setInput(entry.expression)
        requestFocus()
    }

    func remove(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        recalculateAll()
        saveSession()
    }

    func clearHistory() {
        history.removeAll()
        saveSession()
    }

    func clearAll() {
        history.removeAll()
        Engine.reset()
        refreshSymbols()
        refreshPreview()
        saveSession()
    }

    func deleteVariable(_ id: String) {
        Engine.unsetVariable(id)
        refreshSymbols()
    }

    func deleteFunction(_ name: String) {
        Engine.unsetFunction(name)
        refreshSymbols()
    }

    func deleteUnit(_ name: String) {
        Engine.unsetUnit(name)
        refreshSymbols()
    }

    var lastResult: String? { history.last(where: { $0.result != nil })?.result }

    func copyLastResult() {
        if let lastResult { copy(lastResult) }
    }

    func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: History recall (↑/↓)

    func recallPrevious() -> Bool {
        if !completions.isEmpty {
            completionIndex = max(0, completionIndex - 1)
            return true
        }
        let expressions = history.map(\.expression)
        guard !expressions.isEmpty else { return false }
        if recallIndex == nil { draftBeforeRecall = input }
        let next = max(0, (recallIndex ?? expressions.count) - 1)
        recallIndex = next
        setInputSilently(expressions[next])
        return true
    }

    func recallNext() -> Bool {
        if !completions.isEmpty {
            completionIndex = min(completions.count - 1, completionIndex + 1)
            return true
        }
        guard let index = recallIndex else { return false }
        let expressions = history.map(\.expression)
        if index + 1 < expressions.count {
            recallIndex = index + 1
            setInputSilently(expressions[index + 1])
        } else {
            recallIndex = nil
            setInputSilently(draftBeforeRecall)
        }
        return true
    }

    private func setInputSilently(_ text: String) {
        setInput(text)
        completions = []
    }

    // MARK: Completion

    /// The identifier being typed at the end of the input, if any.
    private var trailingIdentifier: Substring {
        let tail = input.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        let ident = input.suffix(tail.count)
        guard let first = ident.first, first.isLetter || first == "_" else { return "" }
        return ident
    }

    private func refreshCompletions() {
        let prefix = trailingIdentifier
        guard prefix.count >= 1 else {
            completions = []
            return
        }
        // Bracketed unit names (`[metre]`) complete against units only.
        let inUnitBracket = input.dropLast(prefix.count).last == "["
        var found = Engine.completions(for: String(prefix))
            .filter { inUnitBracket ? $0.kind == "unit" : $0.kind != "unit" }
        found.sort { lhs, rhs in
            lhs.text.count != rhs.text.count ? lhs.text.count < rhs.text.count : lhs.text < rhs.text
        }
        completions = Array(found.prefix(8))
        completionIndex = 0
    }

    func dismissCompletions() -> Bool {
        guard !completions.isEmpty else { return false }
        completions = []
        return true
    }

    @discardableResult
    func acceptCompletionIfVisible() -> Bool {
        guard completions.indices.contains(completionIndex) else { return false }
        accept(completions[completionIndex])
        return true
    }

    func accept(_ completion: Completion) {
        if completion.kind == "physConst",
           let c = constants.first(where: { $0.name == completion.text }) {
            completions = []
            insert(c.expression)
            return
        }
        let prefix = trailingIdentifier
        var text = String(input.dropLast(prefix.count)) + completion.text
        let isCallable = completion.kind == "function" || completion.kind == "userFunction"
        if isCallable { text += "(" }
        if completion.kind == "unit", input.dropLast(prefix.count).last == "[" { text += "]" }
        setInput(text)
        completions = []
        requestFocus()
    }

    // MARK: Settings

    var engineSettings: EngineSettings {
        EngineSettings(
            angleUnit: angleUnit.rawValue,
            resultFormat: resultFormat.rawValue,
            precision: precision,
            complexNumbers: complexNumbers,
            complexForm: complexForm.rawValue,
            imaginaryUnit: imaginaryUnitJ ? "j" : "i",
            numberFormatStyle: numberStyle.rawValue,
            simplify: simplifyExpressions)
    }

    private func applySettingsToEngine() {
        Engine.apply(engineSettings)
    }

    private func settingsChanged() {
        defaults.set(angleUnit.rawValue, forKey: "angleUnit")
        defaults.set(resultFormat.rawValue, forKey: "resultFormat")
        defaults.set(precision, forKey: "precision")
        defaults.set(complexNumbers, forKey: "complexNumbers")
        defaults.set(complexForm.rawValue, forKey: "complexForm")
        defaults.set(imaginaryUnitJ, forKey: "imaginaryUnitJ")
        defaults.set(numberStyle.rawValue, forKey: "numberStyle")
        defaults.set(simplifyExpressions, forKey: "simplifyExpressions")
        applySettingsToEngine()
        recalculateAll()
        saveSession()
    }

    // MARK: Persistence

    /// Earlier builds of this port were called SpeedCrunch
    /// (org.speedcrunch.mac); bring their settings and session across once.
    private static func migrateFromSpeedCrunchBuild() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedFromSpeedCrunch") else { return }
        d.set(true, forKey: "migratedFromSpeedCrunch")
        if let old = d.persistentDomain(forName: "org.speedcrunch.mac") {
            for (key, value) in old where d.object(forKey: key) == nil {
                d.set(value, forKey: key)
            }
        }
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldSession = support.appendingPathComponent("SpeedCrunch/session.json")
        let newDir = support.appendingPathComponent("Crunchpad", isDirectory: true)
        let newSession = newDir.appendingPathComponent("session.json")
        if fm.fileExists(atPath: oldSession.path), !fm.fileExists(atPath: newSession.path) {
            try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)
            try? fm.copyItem(at: oldSession, to: newSession)
        }
    }

    private var sessionURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Crunchpad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    private func saveSession() {
        guard !restoring else { return }
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: sessionURL, options: .atomic)
        }
    }

    /// Replays the saved transcript so variables, user functions and `ans`
    /// come back exactly as they were.
    private func restoreSession() {
        restoring = true
        defer { restoring = false }
        guard let data = try? Data(contentsOf: sessionURL),
              let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            refreshSymbols()
            return
        }
        history = saved
        recalculateAll()
    }

    private func refreshSymbols() {
        variables = Engine.userVariables()
        userFunctions = Engine.userFunctions()
        userUnits = Engine.userUnits()
    }
}
