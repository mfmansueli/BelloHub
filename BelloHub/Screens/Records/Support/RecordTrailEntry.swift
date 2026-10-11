//
//  RecordTrailEntry.swift
//  BelloHub
//

import Foundation

/// One line of a record's edit trail (4.7): when it was made, locked or corrected.
struct RecordTrailEntry: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case created(source: RecordSource, result: RecordResult, products: [String])
        case locked
        case correction(RecordCorrection)

        /// Breaks a tie between lines with the same time: the later step of the story sorts newer.
        fileprivate var rank: Int {
            switch self {
            case .created: 0
            case .locked: 1
            case .correction: 2
            }
        }
    }

    let id: String
    let date: Date
    let kind: Kind

    var rank: Int { kind.rank }
}
