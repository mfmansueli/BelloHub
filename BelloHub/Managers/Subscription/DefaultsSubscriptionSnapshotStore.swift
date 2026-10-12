//
//  DefaultsSubscriptionSnapshotStore.swift
//  BelloHub
//

import Foundation

/// The snapshot as JSON in `UserDefaults` (`DefaultsKey.subscriptionSnapshot`): a kind, a period, a signed end and a
/// time, nothing personal. An unreadable value reads as none. `@unchecked Sendable` because `UserDefaults` is
/// documented as thread-safe but the SDK does not mark it `Sendable`; remove when it does.
struct DefaultsSubscriptionSnapshotStore: SubscriptionSnapshotStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SubscriptionSnapshot? {
        defaults.data(forKey: DefaultsKey.subscriptionSnapshot)
            .flatMap { try? JSONDecoder().decode(SubscriptionSnapshot.self, from: $0) }
    }

    func save(_ snapshot: SubscriptionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: DefaultsKey.subscriptionSnapshot)
    }
}
