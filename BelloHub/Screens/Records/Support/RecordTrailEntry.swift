//
//  RecordTrailEntry.swift
//  BelloHub
//

import Foundation

/// One line of a record's change history: when it was made, finalized, locked or corrected.
struct RecordTrailEntry: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case created(source: RecordSource, result: RecordResult, products: [String])
        /// A draft became the finalized record (only when that happened after it was first written).
        case finalized
        case locked
        /// A logged change. `entryName` is the template field's name when the correction is about one of her own
        /// fields (`field.<key>`), so the line reads with the name the field had on this record.
        case correction(RecordCorrection, entryName: String?)

        /// Breaks a tie between lines with the same time: the later step of the story sorts newer.
        fileprivate var rank: Int {
            switch self {
            case .created: 0
            case .finalized: 1
            case .locked: 2
            case .correction: 3
            }
        }
    }

    let id: String
    let date: Date
    let kind: Kind

    var rank: Int { kind.rank }
}
