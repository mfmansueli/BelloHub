//
//  IntakeItem.swift
//  BelloHub
//

import Foundation

/// What a new client is asked for before her first visit. Which ones are on is a per-profession choice in
/// onboarding and later in `RecordTemplate` (6.13).
enum IntakeItem: String, PersistedEnum, Identifiable {
    case healthHistory
    case consentForm
    case patchTestLog

    var id: String { rawValue }

    static let fallback = IntakeItem.healthHistory

    /// "Health history", as the label of a switch.
    var title: LocalizedStringResource {
        switch self {
        case .healthHistory: "onb.record.intake.healthHistory"
        case .consentForm: "onb.record.intake.consentForm"
        case .patchTestLog: "onb.record.intake.patchTestLog"
        }
    }

    /// The line under the switch: what the client is asked.
    var hint: LocalizedStringResource {
        switch self {
        case .healthHistory: "onb.record.intake.healthHistoryHint"
        case .consentForm: "onb.record.intake.consentFormHint"
        case .patchTestLog: "onb.record.intake.patchTestLogHint"
        }
    }
}
