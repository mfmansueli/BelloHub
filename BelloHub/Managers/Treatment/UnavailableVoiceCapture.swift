//
//  UnavailableVoiceCapture.swift
//  BelloHub
//

import Foundation

/// The v1 default (D53): voice is not wired yet, so the flow says so and offers the manual form. A DEBUG fake with a
/// scripted transcript lives in the tests target and the UI-test hooks.
@MainActor
final class UnavailableVoiceCapture: VoiceCapturing {
    struct NotAvailable: Error {}

    func availability(for locale: Locale) async -> VoiceAvailability { .notAvailableYet }

    func start(locale: Locale) throws -> AsyncStream<String> { throw NotAvailable() }

    func stop() async -> String { "" }
}
