//
//  VisitReuse.swift
//  BelloHub
//

import Foundation

/// "Use as the base for a new visit": which past record, and which of its parts she chose to copy. Only descriptive
/// parts can be copied. Photos, the result, the reaction, the visit day and signed documents never are: they belong
/// to the visit that happened.
struct VisitReuse: Hashable, Sendable {
    /// A part of a record that may be copied into a new visit.
    enum Part: Hashable, Sendable {
        case technique
        case products
        case aftercare
        case notes
        case nextVisitReminder
        /// One of her template's fields, by key.
        case entry(key: String)
    }

    let recordID: UUID
    var parts: Set<Part>

    /// The parts a record offers for copying: only the ones it actually has, in the order the form shows them.
    static func offeredParts(of record: TreatmentRecord) -> [Part] {
        var parts: [Part] = []
        if !(record.technique ?? "").isEmpty { parts.append(.technique) }
        if !record.productsUsed.isEmpty { parts.append(.products) }
        for entry in record.fieldEntries ?? [] where !entry.value.isEmpty {
            parts.append(.entry(key: entry.key))
        }
        if !(record.aftercare ?? "").isEmpty { parts.append(.aftercare) }
        if !(record.notes ?? "").isEmpty { parts.append(.notes) }
        if !(record.nextVisitReminder ?? "").isEmpty { parts.append(.nextVisitReminder) }
        return parts
    }

    /// What she sees ticked when the sheet opens: how it was done (technique, products, her fields), not what she
    /// wrote about that day (notes, aftercare, what to remember).
    static func defaultParts(of record: TreatmentRecord) -> Set<Part> {
        Set(offeredParts(of: record).filter { part in
            switch part {
            case .technique, .products, .entry: true
            case .aftercare, .notes, .nextVisitReminder: false
            }
        })
    }

    /// Copies the chosen parts of `source` into a new record, never the result, reaction, photos, visit day, ids or
    /// status. `record` keeps everything it already had that was not chosen.
    static func apply(_ parts: Set<Part>, from source: TreatmentRecord, to record: TreatmentRecord) -> TreatmentRecord {
        var copy = record
        if parts.contains(.technique) { copy.technique = source.technique }
        if parts.contains(.products) { copy.productsUsed = source.productsUsed }
        if parts.contains(.aftercare) { copy.aftercare = source.aftercare }
        if parts.contains(.notes) { copy.notes = source.notes }
        if parts.contains(.nextVisitReminder) { copy.nextVisitReminder = source.nextVisitReminder }
        let keys = Set(parts.compactMap { part -> String? in
            guard case .entry(let key) = part else { return nil }
            return key
        })
        let copied = (source.fieldEntries ?? []).filter { keys.contains($0.key) }
        if !copied.isEmpty {
            var entries = (copy.fieldEntries ?? []).filter { !keys.contains($0.key) }
            entries += copied
            copy.fieldEntries = entries
        }
        return copy
    }
}
