//
//  AIPreferences.swift
//  BelloHub
//

import Foundation

/// What she chose for the on-device assistant (7.5, D23). They live on this iPhone only and never reach the server.
/// The two rules that are not a choice are properties, not stored values, so no saved value can ever turn them off.
struct AIPreferences: Equatable, Codable, Sendable {
    /// Dictating a treatment record is offered.
    var voiceEnabled = true
    /// The assistant may organize what she said into her record fields.
    var aiEnabled = true
    /// Audio is removed once the text is ready.
    var deleteRecordingsAfterOrganizing = true

    /// D23: she always checks the draft before it is saved. v1 has no way to turn this off.
    var reviewRequired: Bool { true }
    /// D23: "cloud help" does not exist in v1, so the row is shown disabled.
    var cloudHelpAvailable: Bool { false }

    private enum CodingKeys: String, CodingKey {
        case voiceEnabled, aiEnabled, deleteRecordingsAfterOrganizing
    }
}
