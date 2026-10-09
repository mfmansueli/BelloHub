//
//  ScriptedVoiceCapture.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// `-uiVoice scripted`: a voice capture that "hears" a fixed sentence, a few words at a time, so a UI test can walk the
/// listening, organizing and review screens without a microphone. DEBUG only; it never ships.
@MainActor
final class ScriptedVoiceCapture: VoiceCapturing {
    static let transcript = "Today I did the Brazilian Glow. Her skin was a little sensitive around the cheeks, so I "
        + "reduced the intensity there. I used the calming serum and she responded well. She should come back in "
        + "about four weeks."

    private var heard = ""

    func availability(for locale: Locale) async -> VoiceAvailability { .available }

    func start(locale: Locale) throws -> AsyncStream<String> {
        heard = ""
        let words = Self.transcript.split(separator: " ").map(String.init)
        return AsyncStream { continuation in
            let task = Task { @MainActor in
                var sofar: [String] = []
                for word in words {
                    sofar.append(word)
                    heard = sofar.joined(separator: " ")
                    continuation.yield(heard)
                    if sofar.count.isMultiple(of: 6) { try? await Task.sleep(for: .milliseconds(60)) }
                    if Task.isCancelled { break }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func stop() async -> String {
        heard.isEmpty ? Self.transcript : heard
    }
}
#endif
