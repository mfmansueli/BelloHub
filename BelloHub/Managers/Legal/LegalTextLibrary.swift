//
//  LegalTextLibrary.swift
//  BelloHub
//

/// Where the legal texts the app shows come from. Each signature stores the version and localization it was signed on
/// (ASSUMPTION-24), so a text can always be shown again exactly as it was read.
protocol LegalTextLibrary: Sendable {
    /// The newest version of `document` written in `localization`; when that language has none, the newest in
    /// English. The result says which localization it is in, and that is the one a signature must store.
    func latest(_ document: LegalDocument, localization: AppLocalization) throws -> LegalText

    /// Exactly the text a consent was signed on: this document, in the localization it stored, at that version. There
    /// is no fallback: showing another version as "what she signed" would be false.
    func text(_ document: LegalDocument, localizationID: String, version: String) throws -> LegalText
}
