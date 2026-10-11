//
//  FakeNotificationScheduler.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// A notification center that remembers what it was asked to schedule, so the planning and the rescheduling are tested
/// without scheduling anything on the machine.
final class FakeNotificationScheduler: NotificationScheduling, Sendable {
    private struct State {
        var plans: [[PlannedNotification]] = []
        var removeAllCount = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Every plan handed over, oldest first.
    var plans: [[PlannedNotification]] { state.withLock { $0.plans } }

    /// What is scheduled now: the last plan (each call replaces the previous one), or nothing after a removal.
    var scheduled: [PlannedNotification] { state.withLock { $0.plans.last ?? [] } }

    var removeAllCount: Int { state.withLock { $0.removeAllCount } }

    func replaceScheduled(with notifications: [PlannedNotification]) async {
        state.withLock { $0.plans.append(notifications) }
    }

    func removeAllScheduled() async {
        state.withLock {
            $0.removeAllCount += 1
            $0.plans.append([])
        }
    }
}
