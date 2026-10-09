//
//  VoiceFlowRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("VoiceFlowRules")
struct VoiceFlowRulesTests {
    @Test("Voice is offered only when it is available; every other state makes the form the main path")
    func offer() {
        #expect(VoiceFlowRules.offer(for: .available) == .voiceAndManual)
        #expect(VoiceFlowRules.offer(for: .notAvailableYet) == .manualOnly(.notAvailableYet))
        #expect(VoiceFlowRules.offer(for: .permissionDenied) == .manualOnly(.permissionDenied))
        #expect(VoiceFlowRules.offer(for: .languageUnsupported) == .manualOnly(.languageUnsupported))
    }

    @Test("After listening: nothing heard, organize, or the words as notes when nothing can organize them")
    func afterListening() {
        #expect(VoiceFlowRules.afterListening(transcript: "  \n", structuringAvailable: true) == .nothingHeard)
        #expect(VoiceFlowRules.afterListening(transcript: "hello", structuringAvailable: true) == .organize)
        #expect(
            VoiceFlowRules.afterListening(transcript: "hello", structuringAvailable: false)
                == .formWithTranscriptAsNotes
        )
    }

    @Test("The wrap-up offer comes at three minutes and listening stops by itself at ten")
    func phases() {
        #expect(VoiceFlowRules.phase(elapsed: 179) == .normal)
        #expect(VoiceFlowRules.phase(elapsed: 180) == .askToWrapUp)
        #expect(VoiceFlowRules.phase(elapsed: 600) == .stopNow)
    }
}
