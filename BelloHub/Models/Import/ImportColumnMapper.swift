//
//  ImportColumnMapper.swift
//  BelloHub
//

import Foundation

/// Reads a spreadsheet the way a person would: the titles say which column is the name, the phone and the e-mail, and
/// when they do not (no header, an unknown language) the values do (a column of digits is a phone). The guess is only
/// the first proposal: the mapping step lets her change every choice. Pure and fast: 2,000 rows are mapped in
/// milliseconds.
enum ImportColumnMapper {
    /// Rows looked at when the values decide the column (enough to be sure, few enough to be instant).
    private static let sampleRows = 200
    /// How much of a column's values must look right for the values alone to name it.
    private static let sniffThreshold = 0.6
    private static let longestName = 60

    private static let tokenizedPhrases: [ImportColumnRole: [[String]]] = {
        var result: [ImportColumnRole: [[String]]] = [:]
        for role in ImportColumnRole.allCases { result[role] = ImportHeaderSynonyms.phrases(for: role).map(tokens) }
        return result
    }()

    // MARK: - Header row

    /// Whether the first row holds column titles. It does when any cell names a known part of a client; it does not
    /// when it already holds a phone number or an e-mail; otherwise it does when the rows below carry phones or
    /// e-mails (a row of words over a row of numbers is a title row).
    static func firstRowIsHeader(_ rows: [ImportTable.Row]) -> Bool {
        guard let first = rows.first else { return false }
        let cells = first.cells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if cells.contains(where: { cell in ImportColumnRole.allCases.contains { score(cell, for: $0) > 0 } }) {
            return true
        }
        if cells.contains(where: { looksLikeData($0) }) { return false }
        return rows.dropFirst().prefix(5).contains { row in row.cells.contains { looksLikeData($0) } }
    }

    // MARK: - Detecting the columns

    static func detect(in table: ImportTable) -> ImportColumnMapping {
        var mapping = ImportColumnMapping()
        var claimed = Set<Int>()
        if table.hasHeader {
            for match in titleMatches(in: table.headerTitles) {
                guard mapping[match.role] == nil, !claimed.contains(match.column) else { continue }
                mapping[match.role] = match.column
                claimed.insert(match.column)
            }
        }
        sniffMissingRoles(in: table, mapping: &mapping, claimed: &claimed)
        return mapping
    }

    private struct TitleMatch {
        let role: ImportColumnRole
        let column: Int
        let score: Int
    }

    /// Every (part, column) pair whose title fits, best first: an exact title beats one that merely contains the
    /// phrase ("Ad Soyad" is a full name, not a last name), then the more specific part (e-mail before name), then the
    /// leftmost column. Taking them in this order and skipping a taken part or column gives each part its best column.
    private static func titleMatches(in titles: [String]) -> [TitleMatch] {
        let priority: [ImportColumnRole] = [.email, .phone, .lastName, .name]
        var matches: [TitleMatch] = []
        for (column, title) in titles.enumerated() {
            for role in priority {
                let value = score(title, for: role)
                if value > 0 { matches.append(TitleMatch(role: role, column: column, score: value)) }
            }
        }
        return matches.sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            let leftRank = priority.firstIndex(of: left.role) ?? 0
            let rightRank = priority.firstIndex(of: right.role) ?? 0
            if leftRank != rightRank { return leftRank < rightRank }
            return left.column < right.column
        }
    }

    /// 3 for a title that is exactly one of the role's phrases, 2 for one that contains a phrase, 0 for neither (and 0
    /// for a title that says what *kind* of value a column holds, like "Phone 1 - Label").
    private static func score(_ title: String, for role: ImportColumnRole) -> Int {
        let words = tokens(title)
        guard !words.isEmpty, words.allSatisfy({ !ImportHeaderSynonyms.kindWords.contains($0) }) else { return 0 }
        var best = 0
        for phrase in tokenizedPhrases[role] ?? [] {
            if words == phrase { return 3 }
            if contains(words, phrase) { best = 2 }
        }
        return best
    }

    private static func contains(_ words: [String], _ phrase: [String]) -> Bool {
        guard !phrase.isEmpty, phrase.count <= words.count else { return false }
        for start in 0...(words.count - phrase.count) where Array(words[start..<(start + phrase.count)]) == phrase {
            return true
        }
        return false
    }

    /// Lower case, accents folded, every run of punctuation a separator: "Teléfono (celular)" is `telefono celular`.
    static func tokens(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    // MARK: - Detecting from the values

    private static func sniffMissingRoles(
        in table: ImportTable, mapping: inout ImportColumnMapping, claimed: inout Set<Int>
    ) {
        let sample = table.rows.prefix(sampleRows)
        guard !sample.isEmpty else { return }
        let columns = (0..<table.columnCount).filter { !claimed.contains($0) }

        func ratio(_ column: Int, _ matches: (String) -> Bool) -> Double {
            let values = sample.map { $0.cell(at: column) }.filter { !$0.isEmpty }
            guard !values.isEmpty else { return 0 }
            return Double(values.filter(matches).count) / Double(values.count)
        }
        func best(_ matches: (String) -> Bool) -> Int? {
            var pick: (column: Int, ratio: Double)?
            for column in columns where !claimed.contains(column) {
                let value = ratio(column, matches)
                if value >= sniffThreshold, value > (pick?.ratio ?? 0) { pick = (column, value) }
            }
            return pick?.column
        }

        if mapping.email == nil, let column = best({ ImportEmailRules.check($0) != .none && $0.contains("@") }) {
            mapping.email = column
            claimed.insert(column)
        }
        if mapping.phone == nil, let column = best(ImportPhoneRules.looksLikePhone) {
            mapping.phone = column
            claimed.insert(column)
        }
        if mapping.name == nil, let column = columns.first(where: { column in
            !claimed.contains(column) && ratio(column, looksLikeName) >= sniffThreshold
        }) {
            mapping.name = column
            claimed.insert(column)
        }
    }

    private static func looksLikeName(_ value: String) -> Bool {
        value.count <= longestName && value.contains(where: \.isLetter) && !value.contains(where: \.isNumber)
            && !value.contains("@")
    }

    private static func looksLikeData(_ value: String) -> Bool {
        ImportPhoneRules.looksLikePhone(value) || (value.contains("@") && ImportEmailRules.check(value) != .invalid)
    }

    // MARK: - Candidates

    /// One candidate per data row, in file order. The name is the name column, with the last-name column after it
    /// when it is mapped and the name does not already contain it. `limit` keeps the first rows only (a preview).
    static func candidates(
        from table: ImportTable, mapping: ImportColumnMapping, limit: Int? = nil
    ) -> [ImportCandidate] {
        table.rows.prefix(limit ?? table.rows.count).map { row in
            var name = row.cell(at: mapping.name)
            let last = row.cell(at: mapping.lastName)
            if !last.isEmpty, !name.localizedCaseInsensitiveContains(last) {
                name = name.isEmpty ? last : "\(name) \(last)"
            }
            let email = row.cell(at: mapping.email)
            return ImportCandidate(
                id: "row-\(row.number)",
                name: name,
                phoneNumbers: ImportPhoneRules.numbers(inCell: row.cell(at: mapping.phone)),
                email: email.isEmpty ? nil : email,
                rowNumber: row.number
            )
        }
    }
}
