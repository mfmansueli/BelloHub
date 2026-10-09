//
//  VoiceFlowRules.swift
//  BelloHub
//

import Foundation

/// The decisions of the voice path that are rules and not layout: what the first screen offers, where a finished
/// recording goes, and when the recording asks her to wrap up. Pure, so the table of cases is tested.
enum VoiceFlowRules {
    /// A recording asks gently to finish after three minutes and stops by itself after ten (docs/12 section 2).
    static let softLimit: TimeInterval = 180
    static let hardLimit: TimeInterval = 600

    /// Why voice is not offered. None of them is an error: the manual form is equally complete.
    enum ManualReason: Equatable, Sendable {
        case notAvailableYet
        case permissionDenied
        case languageUnsupported
    }

    enum Offer: Equatable, Sendable {
        case voiceAndManual
        case manualOnly(ManualReason)
    }

    enum AfterListening: Equatable, Sendable {
        /// The transcript is empty: stay and say nothing was heard, never organize silence.
        case nothingHeard
        /// Hand the transcript to the structuring technology.
        case organize
        /// The technology is not available: the transcript becomes her editable notes in the form.
        case formWithTranscriptAsNotes
    }

    enum Phase: Equatable, Sendable {
        case normal
        case askToWrapUp
        case stopNow
    }

    static func offer(for availability: VoiceAvailability) -> Offer {
        switch availability {
        case .available: .voiceAndManual
        case .notAvailableYet: .manualOnly(.notAvailableYet)
        case .permissionDenied: .manualOnly(.permissionDenied)
        case .languageUnsupported: .manualOnly(.languageUnsupported)
        }
    }

    static func hasContent(_ transcript: String) -> Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func afterListening(transcript: String, structuringAvailable: Bool) -> AfterListening {
        guard hasContent(transcript) else { return .nothingHeard }
        return structuringAvailable ? .organize : .formWithTranscriptAsNotes
    }

    static func phase(elapsed: TimeInterval) -> Phase {
        if elapsed >= hardLimit { return .stopNow }
        if elapsed >= softLimit { return .askToWrapUp }
        return .normal
    }
}
