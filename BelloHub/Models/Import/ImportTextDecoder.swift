//
//  ImportTextDecoder.swift
//  BelloHub
//

import Foundation

/// The text of a spreadsheet export, whatever encoding the program wrote it in. Excel for Windows writes
/// Windows-1252 ("CSV (comma delimited)") or UTF-8 with a byte-order mark ("CSV UTF-8"); Numbers and Google Sheets
/// write UTF-8; some Windows tools write UTF-16. The order is: a byte-order mark, UTF-16 without a mark (told by its
/// zero bytes), UTF-8, then Windows-1252 and finally Latin-1 (which accepts any byte, so decoding never fails).
/// Excel for Mac's old "CSV (Macintosh)" is MacRoman and cannot be told apart from Latin-1: it reads with a few wrong
/// accents, which is why the choose step lists the names she is about to import.
enum ImportTextDecoder {
    static func decode(_ data: Data) -> String {
        if data.isEmpty { return "" }
        let bytes = [UInt8](data.prefix(4))
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            if let text = String(data: data, encoding: .utf32) { return strippingMark(text) }
        }
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            if let text = String(data: data.dropFirst(3), encoding: .utf8) { return text }
        }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            if let text = String(data: data, encoding: .utf16) { return strippingMark(text) }
        }
        // Before UTF-8: UTF-16 text in ASCII letters is also valid UTF-8 (every other byte is a NUL), so it must be
        // recognised first.
        if let encoding = utf16WithoutMark(data), let text = String(data: data, encoding: encoding) { return text }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func strippingMark(_ text: String) -> String {
        text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }

    /// Text in ASCII letters written as UTF-16 has a zero byte next to every character: every second byte when it is
    /// little-endian, every other one when it is big-endian.
    private static func utf16WithoutMark(_ data: Data) -> String.Encoding? {
        let sample = [UInt8](data.prefix(200))
        guard sample.count >= 4 else { return nil }
        let even = sample.enumerated().filter { $0.offset.isMultiple(of: 2) && $0.element == 0 }.count
        let odd = sample.enumerated().filter { !$0.offset.isMultiple(of: 2) && $0.element == 0 }.count
        let half = sample.count / 2
        if odd * 3 >= half * 2, even == 0 { return .utf16LittleEndian }
        if even * 3 >= half * 2, odd == 0 { return .utf16BigEndian }
        return nil
    }
}
