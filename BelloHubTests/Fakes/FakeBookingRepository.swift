//
//  FakeBookingRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The booking server in a test: answers the address check from a table, records every call and what was published, and
/// fails as the app would offline or when the server refuses. Lives only in the tests target (CLAUDE.md section 3); the
/// app's own stand-ins are `OfflineBookingRepository` and, in DEBUG, `UITestBookingRepository`.
actor FakeBookingRepository: BookingRepository {
    private var answers: [String: SlugAvailability] = [:]
    private var failure: BookingRepositoryError?
    /// Failures per method name that are used up one by one (the nth call fails with the nth error, then it succeeds).
    private var scripted: [String: [BookingRepositoryError]] = [:]
    private var accountSlug: String?
    private(set) var checked: [String] = []
    /// Every call, as `name` or `name:argument`, in order.
    private(set) var calls: [String] = []
    private(set) var claimedSlugs: [String] = []
    private(set) var profiles: [PublishProfileRequest] = []
    private(set) var availabilities: [PublishAvailabilityRequest] = []
    private(set) var inboxKeys: [InboxPublicKey] = []
    private var delay: Duration?

    func setAnswer(_ answer: SlugAvailability, for slug: String) {
        answers[slug] = answer
    }

    /// Every call throws `error` until set back to nil.
    func setFailure(_ error: BookingRepositoryError?) {
        failure = error
    }

    /// The next calls to `method` fail with these errors, in order.
    func script(_ method: String, failures: [BookingRepositoryError]) {
        scripted[method] = failures
    }

    func setAccountSlug(_ slug: String?) {
        accountSlug = slug
    }

    func setDelay(_ value: Duration?) {
        delay = value
    }

    func isSlugAvailable(_ slug: String) async throws -> SlugAvailability {
        checked.append(slug)
        try await enter("isSlugAvailable", slug)
        return answers[slug] ?? .available
    }

    func ensureAccount(countryCode: String, locale: String) async throws -> AccountInfo {
        try await enter("ensureAccount", "\(countryCode)/\(locale)")
        return AccountInfo(
            uid: "uid", appAccountToken: "token", registrations: .init(count: 0, freeLimit: 10), slug: accountSlug
        )
    }

    func claimSlug(_ slug: String) async throws {
        try await enter("claimSlug", slug)
        claimedSlugs.append(slug)
        accountSlug = slug
    }

    func publishProfile(_ request: PublishProfileRequest) async throws {
        try await enter("publishProfile", nil)
        profiles.append(request)
    }

    func publishAvailability(_ request: PublishAvailabilityRequest) async throws {
        try await enter("publishAvailability", nil)
        availabilities.append(request)
    }

    func setOnlineBookingStopped(phone: String, stopped: Bool) async throws {
        try await enter("setOnlineBookingStopped", "\(phone)/\(stopped)")
    }

    func updateInboxKey(_ key: InboxPublicKey, compromised: Bool) async throws {
        try await enter("updateInboxKey", key.keyId)
        inboxKeys.append(key)
    }

    // MARK: - Private

    private func enter(_ method: String, _ argument: String?) async throws {
        calls.append(argument.map { "\(method):\($0)" } ?? method)
        if let delay { try? await Task.sleep(for: delay) }
        if var queue = scripted[method], !queue.isEmpty {
            let error = queue.removeFirst()
            scripted[method] = queue
            throw error
        }
        if let failure { throw failure }
    }
}
