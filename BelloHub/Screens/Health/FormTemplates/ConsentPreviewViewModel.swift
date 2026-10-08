//
//  ConsentPreviewViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// A consent text as the professional reads it in the form settings: the newest version of one document, in a
/// language she can change. Read-only: the texts are versioned legal drafts, never edited in the app.
@MainActor
@Observable
final class ConsentPreviewViewModel: Identifiable {
    let document: LegalDocument
    private(set) var language: AppLocalization
    private(set) var legalText: LegalText?
    private(set) var renderedText: RenderedLegalText?

    private let legal: any LegalTextLibrary
    private let values: LegalTextValues

    var id: String { document.rawValue }

    init(
        document: LegalDocument,
        language: AppLocalization,
        legal: any LegalTextLibrary = BundleLegalTextLibrary(),
        profile: ProfessionalProfile?
    ) {
        self.document = document
        self.language = language
        self.legal = legal
        self.values = LegalTextValues(profile: profile)
        load()
    }

    func setLanguage(_ language: AppLocalization) {
        guard language != self.language else { return }
        self.language = language
        load()
    }

    var hasError: Bool { legalText == nil }

    private func load() {
        if let found = try? legal.latest(document, localization: language) {
            legalText = found
            renderedText = LegalTextRenderer.render(found, values: values, pending: .forThisBuild)
        } else {
            legalText = nil
            renderedText = nil
        }
    }
}
