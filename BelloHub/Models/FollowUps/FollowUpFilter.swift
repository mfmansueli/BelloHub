//
//  FollowUpFilter.swift
//  BelloHub
//

import Foundation

/// The filters of the follow-up queue: everything, or one family of reasons. The old Follow-ups and Win back screens
/// are two of them now (routine-a item 5).
enum FollowUpFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case reminders
    case visits
    case returns
    case notBack
    case birthdays

    var id: String { rawValue }

    func includes(_ kind: FollowUpKind) -> Bool {
        switch self {
        case .all: true
        case .reminders: kind == .reminder
        case .visits: kind == .postVisit || kind == .unfinishedVisit
        case .returns: kind == .returnDue
        case .notBack: kind == .notBack
        case .birthdays: kind == .birthday
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .all: LocalizedStringResource("followUpQueue.filter.all", defaultValue: "All")
        case .reminders: LocalizedStringResource("followUpQueue.filter.reminders", defaultValue: "Reminders")
        case .visits: LocalizedStringResource("followUpQueue.filter.visits", defaultValue: "After visits")
        case .returns: LocalizedStringResource("followUpQueue.filter.returns", defaultValue: "Returns")
        case .notBack: LocalizedStringResource("followUpQueue.filter.notBack", defaultValue: "Not back")
        case .birthdays: LocalizedStringResource("followUpQueue.filter.birthdays", defaultValue: "Birthdays")
        }
    }
}
