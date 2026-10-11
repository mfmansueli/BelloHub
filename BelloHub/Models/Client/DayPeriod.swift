//
//  DayPeriod.swift
//  BelloHub
//

/// When in the day a client usually books, in the business time zone.
enum DayPeriod: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening

    /// Before noon, noon to 17:59, 18:00 on.
    init(hour: Int) {
        switch hour {
        case ..<12: self = .morning
        case 12..<18: self = .afternoon
        default: self = .evening
        }
    }
}
