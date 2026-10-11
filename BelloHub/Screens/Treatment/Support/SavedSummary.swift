//
//  SavedSummary.swift
//  BelloHub
//

import Foundation

/// The rows of "This session" on the Saved screen (5.6): the record's own text fields first, then her template's own
/// answers. Rows she left empty are not shown, because an empty row reads as something forgotten. The first rows are
/// the preview; the rest sit behind "Show all details".
enum SavedSummary {
    struct Row: Identifiable, Equatable {
        let id: String
        let name: String
        let value: String
    }

    /// How many rows the collapsed card shows.
    static let previewCount = 4

    static func rows(for record: TreatmentRecord, names: Names) -> [Row] {
        var rows: [Row] = []
        func add(_ id: String, _ name: String, _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            rows.append(Row(id: id, name: name, value: value))
        }
        add("notes", names.notes, record.notes)
        add("technique", names.technique, record.technique)
        add("products", names.products, record.productsUsed.joined(separator: ", "))
        add("resultDetail", names.result, record.resultDetail)
        add("aftercare", names.aftercare, record.aftercare)
        for entry in record.fieldEntries ?? [] {
            add("entry.\(entry.key)", entry.name, entryText(entry, names: names))
        }
        return rows
    }

    private static func entryText(_ entry: RecordFieldEntry, names: Names) -> String {
        switch entry.kind {
        case .yesNo: entry.value == RecordFieldEntry.yes ? names.yes : names.no
        case .multiChoice: entry.options.joined(separator: ", ")
        case .number: [entry.value, entry.unit].compactMap { $0 }.joined(separator: " ")
        default: entry.value
        }
    }

    /// The names of the record's own fields, in her language (the view resolves them from the string catalog).
    struct Names: Equatable {
        var notes: String
        var technique: String
        var products: String
        var result: String
        var aftercare: String
        var yes: String
        var no: String
    }
}
