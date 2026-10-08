//
//  PatchTest.swift
//  BelloHub
//

import Foundation

/// One entry of a client's patch-test log: a product tried on a small area, how long the skin was watched and what
/// happened. The professional records it; the client never sends one. It is a dated event of its own, not part of a
/// health form (a form is one signed snapshot of answers), so it has its own kind in the vault (`VaultKind.patchTest`).
/// What was tested and how the skin reacted is health information, so it is encrypted at rest (D26); the date and the
/// hours stay in the clear to sort the log.
struct PatchTest: Identifiable, Hashable, Codable, Sendable {
    /// The observation periods the sheet offers, in hours.
    static let observationOptions = [24, 48, 72]

    let id: UUID
    var clientID: UUID
    var testedAt: Date
    var observedHours: Int

    // Encrypted at rest.
    var product: String
    var area: String?
    var result: PatchTestResult
    var notes: String?
}
