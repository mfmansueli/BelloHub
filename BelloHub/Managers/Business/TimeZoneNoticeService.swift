//
//  TimeZoneNoticeService.swift
//  BelloHub
//

import Foundation
import Observation

/// What the time-zone notice needs to know beyond her profile (tz-mismatch-notice): the iPhone's zone, kept current
/// while the app is open, and the pair of zones she chose to keep, per user in `UserDefaults`. Home and Calendar read
/// the same instance, so "Keep it" on one hides the other at once. Created once in `RootView` (`forApp`);
/// `start(userID:)` when the app is unlocked, `stop()` when it locks or she signs out.
///
/// The pair she kept holds only two zone identifiers, nothing about her clients.
@MainActor
@Observable
final class TimeZoneNoticeService {
    /// The iPhone's time zone right now.
    private(set) var phoneZoneID: String
    /// The pair of zones she kept for the signed-in user; nil when she never chose.
    private(set) var kept: TimeZoneMismatch.Pair?
    /// False hides the notice whatever the zones: a UI-test launch shows it only when the test asks
    /// (`-uiTimeZoneNotice`), because the simulator follows the Mac's zone and every other test would meet it.
    let isEnabled: Bool
    /// The region presets, to say when the iPhone's zone belongs to another country than her business.
    let regions: RegionCatalog

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let phoneZone: @Sendable () -> TimeZone
    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var listenTask: Task<Void, Never>?

    init(
        defaults: UserDefaults,
        regions: RegionCatalog,
        isEnabled: Bool = true,
        phoneZone: @escaping @Sendable () -> TimeZone = { TimeZone.current }
    ) {
        self.defaults = defaults
        self.regions = regions
        self.isEnabled = isEnabled
        self.phoneZone = phoneZone
        phoneZoneID = phoneZone().identifier
    }

    // MARK: - Session

    /// Reads what she kept and starts following the iPhone's zone (she may change it in Settings, or land somewhere
    /// else, while the app is open).
    func start(userID: String) {
        guard self.userID != userID || listenTask == nil else { return }
        stop()
        self.userID = userID
        kept = load(userID: userID)
        refreshPhoneZone()
        listenTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSSystemTimeZoneDidChange) {
                guard !Task.isCancelled else { return }
                self?.refreshPhoneZone()
            }
        }
    }

    /// Forgets the session in memory; what she kept stays stored for the next unlock.
    func stop() {
        listenTask?.cancel()
        listenTask = nil
        userID = nil
        kept = nil
    }

    // MARK: - Actions

    /// Reads the iPhone's zone again (the app came back to the foreground, or iOS said it changed).
    func refreshPhoneZone() {
        // Foundation caches the system zone; drop the cache so a change made in Settings is seen.
        NSTimeZone.resetSystemTimeZone()
        let current = phoneZone().identifier
        if current != phoneZoneID { phoneZoneID = current }
    }

    /// "Keep it": she is not asked again for this pair of zones.
    func keep(_ pair: TimeZoneMismatch.Pair) {
        guard let userID, let data = try? JSONEncoder().encode(pair) else { return }
        defaults.set(data, forKey: Self.key(userID))
        kept = pair
    }

    // MARK: - Private

    private func load(userID: String) -> TimeZoneMismatch.Pair? {
        guard let data = defaults.data(forKey: Self.key(userID)) else { return nil }
        return try? JSONDecoder().decode(TimeZoneMismatch.Pair.self, from: data)
    }

    private static func key(_ userID: String) -> String { DefaultsKey.timeZoneNoticeKept + "." + userID }
}
