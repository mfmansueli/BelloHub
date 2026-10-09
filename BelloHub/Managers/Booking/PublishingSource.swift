//
//  PublishingSource.swift
//  BelloHub
//

import Foundation

/// Where `PublishingService` reads what it publishes, and how it learns that something changed. The app's
/// implementation
/// reads the vault; tests hand over values and fire changes by hand.
@MainActor
protocol PublishingSource {
    /// Everything the page is made from, as of now. Throws `PublishSourceError` or a vault error.
    func inputs(now: Date) async throws -> PublishInputs
    /// Fires once now and after every change to anything in her vault (the publisher compares payloads, so a change
    /// that does not touch the page publishes nothing). Ends when the vault is unavailable.
    func changes() -> AsyncStream<Void>
}

/// Why a source could not give the inputs.
enum PublishSourceError: Error, Equatable {
    /// She has no profile yet (setup not finished).
    case noProfile
    /// The vault or the keys are locked.
    case locked
}
