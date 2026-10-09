//
//  BlockReason.swift
//  BelloHub
//

import Foundation

/// The reasons the Block time sheet offers. Private to her: only she sees it, and it is stored encrypted as the words
/// she saw, so an old block still reads right if she changes the app's language.
enum BlockReason: String, CaseIterable, Identifiable, Sendable {
    case notWell
    case family
    case course
    case holiday
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .notWell: LocalizedStringResource("blockTime.reason.notWell", defaultValue: "Not feeling well")
        case .family: LocalizedStringResource("blockTime.reason.family", defaultValue: "Family")
        case .course: LocalizedStringResource("blockTime.reason.course", defaultValue: "Course or event")
        case .holiday: LocalizedStringResource("blockTime.reason.holiday", defaultValue: "Holiday")
        case .other: LocalizedStringResource("blockTime.reason.other", defaultValue: "Other")
        }
    }
}
