//
//  RecordEntryText.swift
//  BelloHub
//

import Foundation

/// How one of her template answers reads on screen: yes and no in her language, several options as a list, a number
/// with its unit. One owner, so the visit details and "Before you start" read an answer the same way.
enum RecordEntryText {
    static func text(_ entry: RecordFieldEntry, formatters: Formatters, locale: Locale) -> String {
        switch entry.kind {
        case .yesNo:
            switch entry.value {
            case RecordFieldEntry.yes: return LocalizedStringResource("record.entry.yes").resolved(in: locale)
            case RecordFieldEntry.no: return LocalizedStringResource("record.entry.no").resolved(in: locale)
            default: return entry.value
            }
        case .multiChoice:
            return formatters.list(entry.options)
        case .number:
            guard let unit = entry.unit, !unit.isEmpty else { return entry.value }
            return "\(entry.value) \(unit)"
        case .text, .choice:
            return entry.value
        }
    }
}
