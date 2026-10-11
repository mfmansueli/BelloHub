//
//  DayPeriod+Title.swift
//  BelloHub
//

import SwiftUI

extension DayPeriod {
    /// "Mornings", "Afternoons", "Evenings": when she usually books, in the reader's language.
    var title: LocalizedStringKey {
        switch self {
        case .morning: "clientProfile.period.morning"
        case .afternoon: "clientProfile.period.afternoon"
        case .evening: "clientProfile.period.evening"
        }
    }
}
