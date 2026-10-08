//
//  RecordFieldKind.swift
//  BelloHub
//

import Foundation

/// How a field of the treatment record is filled in ("How do you fill it?"). The fields of the profession catalog are
/// all free text; a field she adds herself can be any of the four.
enum RecordFieldKind: String, PersistedEnum, Identifiable {
    /// A sentence or a few words.
    case text
    /// One of the options she listed.
    case choice
    /// A number, with an optional unit ("2.5 mm").
    case number
    /// Yes or no.
    case yesNo

    var id: String { rawValue }

    /// A kind a newer version added reads as free text: whatever was written stays readable.
    static let fallback = RecordFieldKind.text

    /// The name of the kind in the choice "How do you fill it?".
    var title: LocalizedStringResource {
        switch self {
        case .text: "recordTemplate.kind.text"
        case .choice: "recordTemplate.kind.choice"
        case .number: "recordTemplate.kind.number"
        case .yesNo: "recordTemplate.kind.yesNo"
        }
    }
}
