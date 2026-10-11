//
//  Wait.swift
//  BelloHubTests
//

/// Waits for a condition, never for a fixed time (CLAUDE.md section 6). Polls every 10 ms and gives up after `timeout`.
/// The default is long on purpose: a passing test returns at once, and the Fast plan runs hundreds of suites in
/// parallel, so a short limit only turns a busy main actor into a false failure.
enum Wait {
    /// Like `until`, for a condition that reads main-actor state (a ViewModel). The test is `@MainActor`, so the
    /// condition runs where the state lives and nothing non-Sendable crosses an actor boundary.
    @MainActor
    @discardableResult
    static func untilMain(timeout: Duration = .seconds(15), _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @discardableResult
    static func until(timeout: Duration = .seconds(15), _ condition: @Sendable () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await condition()
    }
}
