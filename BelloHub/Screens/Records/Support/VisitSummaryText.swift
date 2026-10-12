//
//  VisitSummaryText.swift
//  BelloHub
//

import Foundation

/// The one-line summary on a visit card: what was done, in her words, most telling first. It reads only what she wrote
/// (never a guess), and stops at a few parts; the card clips it to two lines and the details show everything.
enum VisitSummaryText {
    static let maxParts = 3
    static let maxProducts = 2

    static func make(_ record: TreatmentRecord, list: ([String]) -> String) -> String? {
        var parts: [String] = []
        if let technique = firstLine(record.technique) { parts.append(technique) }
        let products = Array(record.productsUsed.prefix(maxProducts))
        if !products.isEmpty { parts.append(list(products)) }
        for text in [record.resultDetail, record.reaction, record.notes] {
            if let line = firstLine(text) { parts.append(line) }
        }
        for entry in record.fieldEntries ?? [] where entry.kind == .text || entry.kind == .choice {
            if let line = firstLine(entry.value) { parts.append(line) }
        }
        let picked = parts.prefix(maxParts)
        return picked.isEmpty ? nil : picked.joined(separator: " · ")
    }

    private static func firstLine(_ text: String?) -> String? {
        let line = text?
            .split(whereSeparator: \.isNewline).first
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let line, !line.isEmpty else { return nil }
        return line
    }
}
