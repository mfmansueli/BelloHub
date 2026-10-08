//
//  VaultKind.swift
//  BelloHub
//

/// The kinds of record the vault holds. Part of the encryption's associated data (`model`), so renaming a case would
/// make every sealed field of that kind unreadable: **never rename a raw value**.
enum VaultKind: String, CaseIterable, Sendable {
    case client
    case appointment
    case service
    case treatmentRecord
    case correction
    case incident
    case photo
    case healthForm
    case consent
    case sessionPlan
    /// One per client id ever registered (D42). Never deleted.
    case registration
    /// The professional's profile. One per vault.
    case profile
    case tag
    /// Which record fields and intake items she switched on. One per vault.
    case recordTemplate
}
