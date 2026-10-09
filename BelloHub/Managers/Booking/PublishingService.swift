//
//  PublishingService.swift
//  BelloHub
//

import Foundation
import Observation

/// Puts her booking page online and keeps it in step with the app: the profile, the services she offers, her hours and
/// days off, the buffer, notice and window, the pause and the policies. Created once at the root and read with
/// `@Environment(PublishingService.self)`.
///
/// Rules it keeps:
/// - **She decides.** Nothing is published until she taps "Go online" (`goOnline()`); after that every change to her
/// page
///   is published by itself, a moment after she stops editing (debounced), one publish at a time (queued), and only
/// when
///   the payload differs from what the server already has (idempotent).
/// - **Honest offline.** A failed publish never pretends. The state says what failed (`PublishFailure`), the page on
/// the
///   server stays as it was, and a retryable failure is tried again by itself after a growing pause, or at once with
///   `retry()`.
/// - **Clinical data never travels.** The payloads come from `PublishPayloads`, which only knows the public page.
/// - **Nothing outlives the session.** `clear()` runs on lock and sign-out; whether she is "online" is kept per user in
///   `UserDefaults` so a relaunch resumes publishing without asking again.
///
/// There is no unpublish function on the server: `stop()` publishes the page as "not taking bookings" (D15's pause,
/// with
/// no return date) and stops publishing changes; `goOnline()` reverses it.
@MainActor
@Observable
final class PublishingService {
    private(set) var state: PublishState = .notOnline
    /// When the last publish went through.
    private(set) var lastPublishedAt: Date?
    /// The server account, after the first `ensureAccount` of this session (S10 reads `appAccountToken` from it).
    private(set) var account: AccountInfo?

    /// The booking server, shared with the screens that only need the address check.
    @ObservationIgnored let repository: any BookingRepository

    @ObservationIgnored private let source: any PublishingSource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let retryDelays: [Duration]
    @ObservationIgnored private let sleeper: @Sendable (Duration) async throws -> Void

    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var wantsOnline = false
    @ObservationIgnored private var isLive = false
    @ObservationIgnored private var claimedSlug: String?
    @ObservationIgnored private var lastProfile: PublishProfileRequest?
    @ObservationIgnored private var lastAvailability: PublishAvailabilityRequest?
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var listenTask: Task<Void, Never>?

    init(
        repository: any BookingRepository,
        source: any PublishingSource,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        debounce: Duration = .seconds(2),
        retryDelays: [Duration] = [.seconds(15), .seconds(60), .seconds(300)],
        sleeper: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.source = source
        self.defaults = defaults
        self.now = now
        self.debounce = debounce
        self.retryDelays = retryDelays.isEmpty ? [.seconds(60)] : retryDelays
        self.sleeper = sleeper
    }

    // MARK: - Lifecycle

    /// Starts watching her vault for `userID` (call when the app opens, unlocked). If she put the page online from this
    /// phone before, the first change signal brings the server up to date; nothing is published for a user who never
    /// went online.
    func start(userID: String) {
        guard self.userID != userID || listenTask == nil else { return }
        clear()
        self.userID = userID
        wantsOnline = defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == userID
        if wantsOnline {
            // The page was online last time: assume it still is until a publish says otherwise.
            isLive = true
            state = .publishing(wasOnline: true)
        }
        listenTask = Task { [weak self, source] in
            for await _ in source.changes() {
                guard !Task.isCancelled else { return }
                self?.sourceDidChange()
            }
        }
    }

    /// Forgets the session (lock, sign-out): stops every task and empties what was learned. What she chose
    /// (`publishingOnlineUserID`) stays, because locking the app is not stopping her page.
    func clear() {
        listenTask?.cancel()
        debounceTask?.cancel()
        retryTask?.cancel()
        listenTask = nil
        debounceTask = nil
        retryTask = nil
        syncTask?.cancel()
        syncTask = nil
        userID = nil
        wantsOnline = false
        isLive = false
        claimedSlug = nil
        lastProfile = nil
        lastAvailability = nil
        attempt = 0
        isDirty = false
        account = nil
        lastPublishedAt = nil
        state = .notOnline
    }

    /// Sign-out: also forgets that she was online, so the next person to sign in on this phone starts offline.
    func clearForSignOut(userID: String) {
        if defaults.string(forKey: DefaultsKey.publishingOnlineUserID) == userID {
            defaults.removeObject(forKey: DefaultsKey.publishingOnlineUserID)
        }
        clear()
    }

    // MARK: - Actions

    /// Publishes her page now and keeps it published. Fire-and-forget for buttons.
    func goOnline() {
        Task { await goOnlineAsync() }
    }

    func goOnlineAsync() async {
        guard let userID else { return }
        wantsOnline = true
        defaults.set(userID, forKey: DefaultsKey.publishingOnlineUserID)
        await syncNow()
    }

    /// Tries a failed publish again without waiting for the timer.
    func retry() {
        Task { await retryAsync() }
    }

    func retryAsync() async {
        retryTask?.cancel()
        await syncNow()
    }

    /// Takes the page out of service: it stays at its address but says it is not taking bookings, and changes are no
    /// longer published. Returns whether the server accepted it; on a failure she is still online and the state says
    /// why.
    @discardableResult
    func stop() async -> Bool {
        guard userID != nil else { return false }
        retryTask?.cancel()
        debounceTask?.cancel()
        if !isLive {
            forgetWanting()
            state = .notOnline
            return true
        }
        state = .publishing(wasOnline: true)
        do {
            let inputs = try await source.inputs(now: now())
            var request = PublishPayloads.profile(inputs, now: now())
            request.profile.booking.acceptingBookings = false
            request.profile.booking.pausedUntil = nil
            try await repository.publishProfile(request)
        } catch {
            state = .error(Self.failure(for: error), wasOnline: true)
            return false
        }
        forgetWanting()
        isLive = false
        lastProfile = nil
        lastAvailability = nil
        state = .notOnline
        return true
    }

    // MARK: - Changes

    private func sourceDidChange() {
        guard wantsOnline else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self, debounce, sleeper] in
            try? await sleeper(debounce)
            guard !Task.isCancelled else { return }
            // The publish runs in its own task so a later edit cancelling this timer never cancels a request in flight.
            Task { await self?.syncNow() }
        }
    }

    /// Publishes what changed, after any publish already running. Returns when the page is up to date or has failed.
    func syncNow() async {
        guard wantsOnline, userID != nil else { return }
        if let running = syncTask {
            isDirty = true
            await running.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                isDirty = false
                await publishOnce()
            } while isDirty && wantsOnline
            syncTask = nil
        }
        syncTask = task
        await task.value
    }

    // MARK: - One publish

    private func publishOnce() async {
        retryTask?.cancel()
        state = .publishing(wasOnline: isLive)
        do {
            let inputs = try await source.inputs(now: now())
            if let blocker = PublishPayloads.blocker(inputs) {
                state = .error(blocker, wasOnline: isLive)
                return
            }
            let profile = PublishPayloads.profile(inputs, now: now())
            let availability = PublishPayloads.availability(inputs, now: now())
            try await ensureAccountAndAddress(inputs)
            if profile != lastProfile {
                try await repository.publishProfile(profile)
                lastProfile = profile
            }
            if availability != lastAvailability {
                try await repository.publishAvailability(availability)
                lastAvailability = availability
            }
            isLive = true
            attempt = 0
            lastPublishedAt = now()
            state = profile.profile.booking.acceptingBookings
                ? .online : .paused(until: profile.profile.booking.pausedUntil)
        } catch {
            fail(with: Self.failure(for: error))
        }
    }

    /// The server needs an account before anything else, and the address under her name before the page.
    private func ensureAccountAndAddress(_ inputs: PublishInputs) async throws {
        if account == nil {
            let info = try await repository.ensureAccount(
                countryCode: inputs.profile.regionCode, locale: inputs.profile.appLocaleID
            )
            account = info
            claimedSlug = info.slug
        }
        guard let slug = inputs.setup.slug, slug != claimedSlug else { return }
        try await repository.claimSlug(slug)
        claimedSlug = slug
        // Claiming replaces the old address and removes its public page: publish the page again under the new one.
        lastProfile = nil
    }

    private func fail(with failure: PublishFailure) {
        state = .error(failure, wasOnline: isLive)
        if failure == .addressTaken { claimedSlug = nil }
        guard failure.isRetryable, wantsOnline else { return }
        let delay = retryDelays[min(attempt, retryDelays.count - 1)]
        attempt += 1
        retryTask = Task { [weak self, sleeper] in
            try? await sleeper(delay)
            guard !Task.isCancelled else { return }
            Task { await self?.syncNow() }
        }
    }

    private func forgetWanting() {
        wantsOnline = false
        defaults.removeObject(forKey: DefaultsKey.publishingOnlineUserID)
    }

    // MARK: - Mapping

    /// Any error a publish can end in, as the failure the screens explain.
    static func failure(for error: any Error) -> PublishFailure {
        switch error {
        case let error as BookingRepositoryError: failure(for: error)
        case let error as ServerError: failure(for: error)
        case let error as PublishSourceError: error == .locked ? .locked : .rejected
        case VaultError.locked: .locked
        default: .rejected
        }
    }

    private static func failure(for error: BookingRepositoryError) -> PublishFailure {
        switch error {
        case .unreachable, .notPublishedYet: .offline
        case .busy: .busy
        case .unauthenticated: .signedOut
        case .slugTaken: .addressTaken
        case .slugInvalid, .rejected: .rejected
        }
    }

    private static func failure(for error: ServerError) -> PublishFailure {
        switch error {
        case .network: .offline
        case .unavailable, .rateLimited: .busy
        case .unauthenticated, .forbidden: .signedOut
        case .slugTaken: .addressTaken
        default: .rejected
        }
    }
}
