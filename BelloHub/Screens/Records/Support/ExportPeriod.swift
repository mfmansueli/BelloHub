//
//  ExportPeriod.swift
//  BelloHub
//

import Foundation

/// How far back the export reaches (4.10).
enum ExportPeriod: String, CaseIterable, Identifiable, Sendable {
    case allTime
    case last12Months

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .allTime: "exportRecord.period.all"
        case .last12Months: "exportRecord.period.year"
        }
    }

    /// The earliest moment the export includes, or nil for everything.
    func start(now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .allTime: nil
        case .last12Months: calendar.date(byAdding: .month, value: -12, to: now)
        }
    }
}
