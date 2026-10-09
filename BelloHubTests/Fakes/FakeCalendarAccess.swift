//
//  FakeCalendarAccess.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// A calendar whose access a test sets, and that answers a request with a scripted status.
final class FakeCalendarAccess: CalendarAccessProviding, Sendable {
    private struct State {
        var current: CalendarAccessStatus
        var answer: CalendarAccessStatus
        var requests = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(current: CalendarAccessStatus = .notDetermined, answer: CalendarAccessStatus = .full) {
        state = OSAllocatedUnfairLock(initialState: State(current: current, answer: answer))
    }

    var requests: Int { state.withLock { $0.requests } }

    func status() -> CalendarAccessStatus {
        state.withLock { $0.current }
    }

    func requestFullAccess() async -> CalendarAccessStatus {
        state.withLock { state in
            state.requests += 1
            state.current = state.answer
            return state.answer
        }
    }
}
