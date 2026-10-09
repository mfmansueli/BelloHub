//
//  ConsentPresentation.swift
//  BelloHub
//

import SwiftUI

/// The words that describe a consent, in one place: its title, who signed it and when, and the version of the text.
/// The consent row, the signed-text sheet and the form settings all say these the same way.
enum ConsentPresentation {
    static func title(of kind: ConsentKind) -> LocalizedStringKey {
        switch kind {
        case .treatment: "health.consent.treatment"
        case .photos: "health.consent.photos"
        case .guardian: "health.consent.guardian"
        }
    }

    /// The title of the document a consent of this kind is signed on (the form settings list the documents).
    static func title(of document: LegalDocument) -> LocalizedStringKey {
        switch document {
        case .consentHealth: title(of: ConsentKind.treatment)
        case .consentPhoto: title(of: ConsentKind.photos)
        case .consentGuardian: title(of: ConsentKind.guardian)
        }
    }

    /// "Signed by Ana Costa · Sep 12", or "Signed · Sep 12" when no name was typed.
    static func signedLine(_ consent: Consent, formatters: Formatters, locale: Locale) -> String {
        let date = BidiIsolate.wrap(formatters.shortDate(consent.signedAt))
        let name = consent.typedSignature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resource: LocalizedStringResource = name.isEmpty
            ? LocalizedStringResource("health.consent.signed", defaultValue: "Signed · \(date)")
            : LocalizedStringResource(
                "health.consent.signedBy", defaultValue: "Signed by \(BidiIsolate.wrap(name)) · \(date)"
            )
        return String(localized: resource.localized(in: locale))
    }

    /// "Text version 2026-10".
    static func versionLine(_ version: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(
            "health.consent.version", defaultValue: "Text version \(BidiIsolate.wrapLeftToRight(version))"
        ).localized(in: locale))
    }
}
