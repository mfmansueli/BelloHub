//
//  VoiceCapturing.swift
//  BelloHub
//

import Foundation

/// Dictation of a treatment record. The speech technology sits behind this protocol (D53): the screens only know
/// "is it available", "start" and "stop", so the owner can swap the implementation after v1 without touching them.
/// Audio never leaves the iPhone and is never stored; only the transcript the professional reviews is kept.
@MainActor
protocol VoiceCapturing: AnyObject {
    func availability(for locale: Locale) async -> VoiceAvailability
    /// Starts listening; the stream carries the transcript so far, replaced (not appended) at every update, until
    /// `stop()`. Throws when `availability` is not `.available`.
    func start(locale: Locale) throws -> AsyncStream<String>
    /// Stops listening and returns the final transcript.
    func stop() async -> String
}
