//
//  MailboxKind.swift
//  BelloHub
//

/// What a sealed envelope carries (docs/06-PRIVACY-SECURITY.md section 3.4). The kind is in the clear on the server
/// (it bounds the size) and inside the AAD, so a swapped kind does not open.
enum MailboxKind: String, PersistedEnum {
    /// A health form the client filled in her browser.
    case intake
    /// How she feels after the visit, maybe with a photo.
    case checkin
    /// A copy or deletion request (D30).
    case datarequest

    static let fallback = MailboxKind.intake
}
