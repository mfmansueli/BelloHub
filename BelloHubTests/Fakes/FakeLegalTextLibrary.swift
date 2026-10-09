//
//  FakeLegalTextLibrary.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// A legal text library a test scripts: the texts it holds, and every localization it was asked for.
final class FakeLegalTextLibrary: LegalTextLibrary {
    private struct State {
        var texts: [LegalText] = []
        var requests: [String] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    init(_ texts: [LegalText] = []) {
        state.withLock { $0.texts = texts }
    }

    /// `document-localization` for every `latest` call, in order.
    var requests: [String] { state.withLock { $0.requests } }

    func latest(_ document: LegalDocument, localization: AppLocalization) throws -> LegalText {
        state.withLock { $0.requests.append("\(document.rawValue)-\(localization.rawValue)") }
        let candidates = state.withLock { $0.texts.filter { $0.document == document } }
        let versions = candidates.filter { $0.localization == localization.rawValue }.map(\.version)
        let fallback = candidates.filter { $0.localization == "en" }.map(\.version)
        for (localizationID, available) in [(localization.rawValue, versions), ("en", fallback)] {
            if let version = LegalFileName.newest(of: available),
               let text = candidates.first(where: { $0.localization == localizationID && $0.version == version }) {
                return text
            }
        }
        throw LegalTextError.notFound
    }

    func text(_ document: LegalDocument, localizationID: String, version: String) throws -> LegalText {
        let found = state.withLock {
            $0.texts.first { $0.document == document && $0.localization == localizationID && $0.version == version }
        }
        guard let found else { throw LegalTextError.notFound }
        return found
    }

    /// A short text for `document` in `localization` at `version`, with the professional's name in it.
    static func text(
        _ document: LegalDocument, localization: String = "en", version: String = "2026-10"
    ) -> LegalText {
        LegalText(
            document: document, localization: localization, version: version, region: "Test", status: "draft",
            framework: "", body: "# \(document.rawValue) \(localization) \(version)\n\n**Who.** {{PROFESSIONAL_NAME}}."
        )
    }
}
