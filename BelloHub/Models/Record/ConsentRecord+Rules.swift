//
//  ConsentRecord+Rules.swift
//  BelloHub
//

import Foundation

/// The rules of a consent record that more than one feature reads (the vault, the health screen, the export), so
/// each has one owner.
extension ConsentRecord {
    /// The order every list shows them in: the most recent first (the signing date, or the day the note was made),
    /// ties broken by id so two phones agree.
    static func newestFirst(_ records: some Sequence<ConsentRecord>) -> [ConsentRecord] {
        records.sorted { left, right in
            if left.effectiveDate != right.effectiveDate { return left.effectiveDate > right.effectiveDate }
            return left.id.uuidString < right.id.uuidString
        }
    }

    /// The label a row or a document shows: hers when she wrote one, else the kind's title (resolved by the caller
    /// in the reader's language).
    func displayLabel(kindTitle: String) -> String {
        let own = (label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? kindTitle : own
    }
}
