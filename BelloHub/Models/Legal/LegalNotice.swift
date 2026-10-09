//
//  LegalNotice.swift
//  BelloHub
//

import Foundation

/// The two legal texts the professional herself reads in Privacy and security: the terms of use with the data
/// processing agreement, and the privacy policy. They are bundled like the consent texts (`legal/<document>/`), but are
/// kept apart from `LegalDocument` because nothing is ever signed on them inside a client's record. The raw value is
/// the folder name and the bundled file prefix, so **never rename one**.
enum LegalNotice: String, CaseIterable, Identifiable, Sendable {
    case termsAndDPA = "terms-dpa"
    case privacyPolicy = "privacy-policy"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .termsAndDPA: "privacy.legal.terms"
        case .privacyPolicy: "privacy.legal.privacyPolicy"
        }
    }
}
