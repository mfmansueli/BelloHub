//
//  ImportTable.swift
//  BelloHub
//

import Foundation

/// The rows of a spreadsheet as the mapping step needs them: an optional header row and the data rows, each with its
/// row number in the file. Blank rows ("ghost" rows of commas that Excel leaves at the end) are dropped here.
struct ImportTable: Equatable, Sendable {
    struct Row: Equatable, Sendable {
        let number: Int
        let cells: [String]

        /// The trimmed cell of `column`, or "" when the column is absent or the row is shorter.
        func cell(at column: Int?) -> String {
            guard let column, cells.indices.contains(column) else { return "" }
            return cells[column].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    let delimiter: CSVDelimiter
    /// Every non-blank row of the file, the header included.
    private let allRows: [Row]
    private(set) var hasHeader: Bool
    /// The first row, when it holds column titles.
    private(set) var header: Row?
    private(set) var rows: [Row]

    /// `hasHeader` nil lets `ImportColumnMapper` decide from the content.
    init(document: CSVDocument, hasHeader: Bool? = nil) {
        let all = document.records
            .filter { record in record.fields.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
            .map { Row(number: $0.number, cells: $0.fields) }
        delimiter = document.delimiter
        allRows = all
        let usesHeader = hasHeader ?? ImportColumnMapper.firstRowIsHeader(all)
        self.hasHeader = usesHeader && !all.isEmpty
        header = self.hasHeader ? all.first : nil
        rows = self.hasHeader ? Array(all.dropFirst()) : all
    }

    var columnCount: Int {
        max(header?.cells.count ?? 0, rows.reduce(0) { max($0, $1.cells.count) })
    }

    /// The title of each column; empty when the file has no header or the cell is blank.
    var headerTitles: [String] {
        (0..<columnCount).map { header?.cell(at: $0) ?? "" }
    }

    var isEmpty: Bool { rows.isEmpty }

    /// The same file with its first row read as a header, or not (she can correct a wrong guess).
    func settingHeader(_ hasHeader: Bool) -> ImportTable {
        var copy = self
        copy.hasHeader = hasHeader && !allRows.isEmpty
        copy.header = copy.hasHeader ? allRows.first : nil
        copy.rows = copy.hasHeader ? Array(allRows.dropFirst()) : allRows
        return copy
    }
}
