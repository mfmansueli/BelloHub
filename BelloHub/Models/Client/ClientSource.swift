//
//  ClientSource.swift
//  BelloHub
//

/// How a client came to be in the professional's list.
enum ClientSource: String, PersistedEnum {
    case bookingLink
    case importedClients = "import"
    case manual
    case referral

    static let fallback = ClientSource.manual
}
