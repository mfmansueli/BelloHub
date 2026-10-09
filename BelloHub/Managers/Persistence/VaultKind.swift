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
    /// One version of the health form she asks. Versions are kept, never rewritten (S4).
    case healthFormTemplate
    /// One entry of a client's patch-test log (S4).
    case patchTest
    /// An extra a client can add to a service (S5).
    case addOn
    /// A product she sells or uses (S5).
    case product
    /// One of her trainings or certificates (S5).
    case credential
    /// Weekly hours, breaks, days off and buffer. One per vault (S5).
    case availability
    /// The booking page switches and its cancel and no-show policies. One per vault (S5).
    case bookingSetup
    /// One quick reply she sends clients (S5).
    case quickReply
    /// A stretch she closed in the calendar (S6). The reason is sealed.
    case timeBlock
}
