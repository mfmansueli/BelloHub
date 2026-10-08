//
//  IntakeItem.swift
//  BelloHub
//

/// What a new client is asked for before her first visit. Which ones are on is a per-profession choice in
/// onboarding and later in `RecordTemplate` (6.13).
enum IntakeItem: String, PersistedEnum, Identifiable {
    case healthHistory
    case consentForm
    case patchTestLog

    var id: String { rawValue }

    static let fallback = IntakeItem.healthHistory
}
