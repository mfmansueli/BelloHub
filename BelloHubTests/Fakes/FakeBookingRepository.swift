//
//  FakeBookingRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The booking server in a test: answers the address check from a table, or fails as the app would offline. Lives
/// only in the tests target (CLAUDE.md section 3); the app's own stand-in is `OfflineBookingRepository`.
actor FakeBookingRepository: BookingRepository {
    private var answers: [String: SlugAvailability] = [:]
    private var failure: BookingRepositoryError?
    private(set) var checked: [String] = []

    func setAnswer(_ answer: SlugAvailability, for slug: String) {
        answers[slug] = answer
    }

    /// Every call throws `error` until set back to nil.
    func setFailure(_ error: BookingRepositoryError?) {
        failure = error
    }

    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability {
        checked.append(slug)
        if let failure { throw failure }
        return answers[slug] ?? .available
    }
}
