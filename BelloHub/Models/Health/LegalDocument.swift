//
//  LegalDocument.swift
//  BelloHub
//

/// The legal documents the app itself shows and has signed (`legal/<document>/`). The raw value is the folder name
/// and the first part of the bundled file name, so **never rename one**. The other legal documents (terms, privacy
/// policy, client notice, data requests) are not shown inside the health and consent screens.
enum LegalDocument: String, CaseIterable, Hashable, Sendable {
    case consentHealth = "consent-health"
    case consentPhoto = "consent-photo"
    case consentGuardian = "consent-guardian"
}
