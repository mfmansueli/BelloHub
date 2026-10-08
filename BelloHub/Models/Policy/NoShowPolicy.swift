//
//  NoShowPolicy.swift
//  BelloHub
//

import Foundation

/// No-show protection, per professional. A cancellation by the professional never counts against a client.
struct NoShowPolicy: Hashable, Codable, Sendable {
    var isOn: Bool
    /// Allowed no-shows before the action applies: 1 to 5.
    var limit: Int
    var action: NoShowAction
    /// A late cancellation (inside the policy's free window) also counts toward the limit.
    var lateCancelCounts: Bool
    /// Older no-shows stop counting by themselves, so one bad day never follows a client forever.
    var countingMonths: Int

    static let limitRange = 1...5
    static let countingMonthOptions = [3, 6, 12]

    static let standard = NoShowPolicy(isOn: true, limit: 3, action: .tell, lateCancelCounts: false, countingMonths: 12)
}
