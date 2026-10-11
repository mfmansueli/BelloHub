//
//  NoShowCountMessage.swift
//  BelloHub
//

import Foundation

/// Which sentence the count card says (3.7 and 4.11). The numbers and the rule come from `NoShowStatus` and
/// `NoShowPolicy`; this only chooses the wording, so the two screens say the same thing.
enum NoShowCountMessage: Equatable, Sendable {
    /// Protection is off: misses are kept in the history and nothing happens.
    case protectionOff
    /// Under the limit: `remaining` more reaches it.
    case counting(counted: Int, limit: Int, remaining: Int, months: Int)
    /// At or over the limit: the action of the rule applies.
    case limitReached(action: NoShowAction, months: Int)

    static func make(status: NoShowStatus, policy: NoShowPolicy) -> NoShowCountMessage {
        guard status.isProtectionOn else { return .protectionOff }
        if status.limitReached { return .limitReached(action: policy.action, months: policy.countingMonths) }
        return .counting(
            counted: status.counted, limit: status.limit, remaining: status.remainingBeforeLimit,
            months: policy.countingMonths
        )
    }

    /// The card uses the warning colors.
    var isAlert: Bool {
        if case .limitReached = self { return true }
        return false
    }
}
