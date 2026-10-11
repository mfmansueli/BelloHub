//
//  CSVTable.swift
//  BelloHub
//

import Foundation

/// A spreadsheet as RFC 4180 text: a header row, then one row per record, every cell quoted when it holds a comma,
/// a quote, or a line break. UTF-8 with a BOM so Excel for Windows reads accents (the import's parser accepts the
/// same file back). Pure, so the exact bytes are tested.
struct CSVTable: Equatable, Sendable {
    let header: [String]
    let rows: [[String]]

    var text: String {
        ([header] + rows).map { row in row.map(Self.escaped).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    var data: Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    static func escaped(_ cell: String) -> String {
        guard cell.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return cell }
        return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
