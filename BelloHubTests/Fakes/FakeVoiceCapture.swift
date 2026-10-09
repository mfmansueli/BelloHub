//
//  FakeVoiceCapture.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// Voice capture that says what it is told: an availability, then one transcript. The stream stays open until
/// `stop()`, like the real one.
@MainActor
final class FakeVoiceCapture: VoiceCapturing {
    var availabilityAnswer = VoiceAvailability.available
    var transcript = "Brazilian Glow, calming serum, she responded well."
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var continuation: AsyncStream<String>.Continuation?

    func availability(for locale: Locale) async -> VoiceAvailability { availabilityAnswer }

    func start(locale: Locale) throws -> AsyncStream<String> {
        startCount += 1
        let (stream, continuation) = AsyncStream<String>.makeStream()
        self.continuation = continuation
        continuation.yield(transcript)
        return stream
    }

    func stop() async -> String {
        stopCount += 1
        continuation?.finish()
        return transcript
    }
}
