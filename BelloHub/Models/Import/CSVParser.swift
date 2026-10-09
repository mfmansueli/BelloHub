//
//  CSVParser.swift
//  BelloHub
//

import Foundation

/// The field separators spreadsheets use: Excel in English locales writes commas, in most others semicolons (the
/// comma is their decimal mark), and Numbers and Google Sheets can write tabs.
enum CSVDelimiter: UInt8, CaseIterable, Sendable {
    case comma = 0x2C
    case semicolon = 0x3B
    case tab = 0x09
}

/// One record of a file. `number` counts every record of the file, blank ones included, so it matches the row number
/// Excel and Numbers show and "row 12" in a message points at the row she sees.
struct CSVRecord: Equatable, Sendable {
    let number: Int
    let fields: [String]
}

struct CSVDocument: Equatable, Sendable {
    let delimiter: CSVDelimiter
    let records: [CSVRecord]
}

/// A tolerant RFC 4180 reader. Quoted fields may hold the delimiter, line breaks and `""` for a quote; line breaks
/// may be CRLF, LF or CR; a byte-order mark at the start is skipped; the delimiter is detected when not given.
/// A line with nothing on it is not a record (it only advances `number`), which also drops trailing empty lines.
/// Pure and byte-based: the delimiters, quotes and breaks are ASCII, which never occurs inside another UTF-8
/// character, so scanning bytes is safe and fast (2,000 rows parse in a few milliseconds).
enum CSVParser {
    private static let quote: UInt8 = 0x22
    private static let lineFeed: UInt8 = 0x0A
    private static let carriageReturn: UInt8 = 0x0D
    private static let space: UInt8 = 0x20
    /// Lines looked at to guess the delimiter: enough to be sure, few enough to stay instant on a big file.
    private static let sampleLines = 12
    private static let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]

    static func parse(_ text: String, delimiter: CSVDelimiter? = nil) -> CSVDocument {
        var bytes = Array(text.utf8)
        if bytes.starts(with: byteOrderMark) { bytes.removeFirst(byteOrderMark.count) }
        let separator = delimiter ?? detectDelimiter(in: bytes)
        return CSVDocument(delimiter: separator, records: records(in: bytes, separator: separator.rawValue))
    }

    // MARK: - Reading

    private struct Reader {
        let separator: UInt8
        var records: [CSVRecord] = []
        var fields: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        var wasQuoted = false
        var hasContent = false
        var number = 0

        init(separator: UInt8) {
            self.separator = separator
        }

        mutating func read(_ bytes: [UInt8]) -> [CSVRecord] {
            var index = 0
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if inQuotes {
                    readQuoted(byte, in: bytes, at: &index)
                } else {
                    readUnquoted(byte, in: bytes, at: &index)
                }
            }
            if hasContent || !field.isEmpty || !fields.isEmpty { endRecord() }
            return records
        }

        /// Inside quotes everything is text, line breaks included; `""` is one quote and a lone quote closes.
        private mutating func readQuoted(_ byte: UInt8, in bytes: [UInt8], at index: inout Int) {
            guard byte == CSVParser.quote else {
                field.append(byte)
                return
            }
            if index < bytes.count, bytes[index] == CSVParser.quote {
                field.append(byte)
                index += 1
            } else {
                inQuotes = false
            }
        }

        private mutating func readUnquoted(_ byte: UInt8, in bytes: [UInt8], at index: inout Int) {
            switch byte {
            case CSVParser.quote where !wasQuoted && field.allSatisfy({ $0 == CSVParser.space }):
                // A quote opens a field, even after spaces: `a, "b, c"` is two fields.
                field.removeAll(keepingCapacity: true)
                wasQuoted = true
                hasContent = true
                inQuotes = true
            case separator:
                hasContent = true
                endField()
            case CSVParser.carriageReturn:
                if index < bytes.count, bytes[index] == CSVParser.lineFeed { index += 1 }
                endRecord()
            case CSVParser.lineFeed:
                endRecord()
            default:
                hasContent = true
                field.append(byte)
            }
        }

        private mutating func endField() {
            fields.append(String(bytes: field, encoding: .utf8) ?? "")
            field.removeAll(keepingCapacity: true)
            wasQuoted = false
        }

        private mutating func endRecord() {
            endField()
            number += 1
            let isBlankLine = fields.count == 1 && fields[0].isEmpty && !hasContent
            if !isBlankLine { records.append(CSVRecord(number: number, fields: fields)) }
            fields.removeAll(keepingCapacity: true)
            hasContent = false
        }
    }

    private static func records(in bytes: [UInt8], separator: UInt8) -> [CSVRecord] {
        var reader = Reader(separator: separator)
        return reader.read(bytes)
    }

    // MARK: - Delimiter

    /// The delimiter that splits the first lines into the same number of fields as the header does. A file with no
    /// delimiter at all (one column of names) reads as comma-separated: one field per line.
    static func detectDelimiter(in bytes: [UInt8]) -> CSVDelimiter {
        let counts = delimiterCounts(in: bytes)
        guard let header = counts.first else { return .comma }
        var best = CSVDelimiter.comma
        var bestScore = 0
        for delimiter in CSVDelimiter.allCases {
            let headerCount = header[delimiter] ?? 0
            guard headerCount > 0 else { continue }
            // Lines that agree with the header weigh most; the header's own width breaks ties.
            let agreeing = counts.filter { ($0[delimiter] ?? 0) == headerCount }.count
            let score = agreeing * 1000 + headerCount
            if score > bestScore {
                bestScore = score
                best = delimiter
            }
        }
        return best
    }

    /// For each of the first lines that have something on them, how many times each delimiter appears outside quotes.
    private static func delimiterCounts(in bytes: [UInt8]) -> [[CSVDelimiter: Int]] {
        var lines: [[CSVDelimiter: Int]] = []
        var current: [CSVDelimiter: Int] = [:]
        var hasContent = false
        var inQuotes = false
        func finishLine() {
            if hasContent { lines.append(current) }
            current = [:]
            hasContent = false
        }
        for byte in bytes {
            if lines.count >= sampleLines { break }
            if byte == quote {
                inQuotes.toggle()
                hasContent = true
            } else if inQuotes {
                hasContent = true
            } else if byte == lineFeed || byte == carriageReturn {
                finishLine()
            } else {
                hasContent = true
                if let delimiter = CSVDelimiter(rawValue: byte) { current[delimiter, default: 0] += 1 }
            }
        }
        if lines.count < sampleLines { finishLine() }
        return lines
    }
}
