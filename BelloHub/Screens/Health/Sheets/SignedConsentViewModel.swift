//
//  SignedConsentViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// Shows the exact text a consent was signed on: the document of its kind, in the localization it stored, at the
/// version it stored. There is no fallback to another version, because that would be shown as "what was signed".
@MainActor
@Observable
final class SignedConsentViewModel: Identifiable {
    let consent: Consent
    /// Writes the date of the signature in the business time zone.
    let formatters: Formatters
    /// Nil when this iPhone does not have that version (it was signed on a newer build of the app).
    let legalText: LegalText?
    let renderedText: RenderedLegalText?

    var id: UUID { consent.id }

    init(
        consent: Consent,
        formatters: Formatters,
        legal: any LegalTextLibrary = BundleLegalTextLibrary(),
        profile: ProfessionalProfile?
    ) {
        self.consent = consent
        self.formatters = formatters
        let found = try? legal.text(
            consent.kind.legalDocument, localizationID: consent.localeID, version: consent.textVersion
        )
        self.legalText = found
        self.renderedText = found.map {
            LegalTextRenderer.render($0, values: LegalTextValues(profile: profile), pending: .forThisBuild)
        }
    }

    var isMissing: Bool { legalText == nil }

    /// The language the signed text is written in.
    var localization: AppLocalization? { AppLocalization(rawValue: consent.localeID) }
}
