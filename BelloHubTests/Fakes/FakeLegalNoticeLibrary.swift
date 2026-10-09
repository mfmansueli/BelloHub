//
//  FakeLegalNoticeLibrary.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// A terms-and-policy library a test scripts: the texts it holds (by notice and localization) and what it was asked.
final class FakeLegalNoticeLibrary: LegalNoticeLibrary, Sendable {
    private struct State {
        var texts: [LegalNoticeText]
        var requests: [String] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(_ texts: [LegalNoticeText] = []) {
        state = OSAllocatedUnfairLock(initialState: State(texts: texts))
    }

    var requests: [String] { state.withLock { $0.requests } }

    func latest(_ notice: LegalNotice, localization: AppLocalization) throws -> LegalNoticeText {
        try state.withLock { state in
            state.requests.append("\(notice.rawValue)-\(localization.rawValue)")
            let candidates = state.texts.filter { $0.notice == notice }
            if let own = candidates.first(where: { $0.localization == localization.rawValue }) { return own }
            if let english = candidates.first(where: { $0.localization == "en" }) { return english }
            throw LegalTextError.notFound
        }
    }
}
