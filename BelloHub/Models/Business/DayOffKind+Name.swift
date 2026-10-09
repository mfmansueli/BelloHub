//
//  DayOffKind+Name.swift
//  BelloHub
//

import Foundation

extension DayOffKind {
    /// What she calls this kind of closed days. Look it up with `.localized(in:)` so it follows the screen's language.
    var name: LocalizedStringResource {
        switch self {
        case .dayOff: LocalizedStringResource("availability.dayOff.kind.dayOff", defaultValue: "Day off")
        case .vacation: LocalizedStringResource("availability.dayOff.kind.vacation", defaultValue: "Vacation")
        case .blocked: LocalizedStringResource("availability.dayOff.kind.blocked", defaultValue: "Blocked")
        }
    }
}
