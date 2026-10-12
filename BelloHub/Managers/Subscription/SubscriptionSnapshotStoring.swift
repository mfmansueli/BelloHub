//
//  SubscriptionSnapshotStoring.swift
//  BelloHub
//

import Foundation

/// Where the last proven plan state is kept on this iPhone (`SubscriptionSnapshot`, D59). The app keeps it in
/// `UserDefaults`; tests use an in-memory fake.
protocol SubscriptionSnapshotStoring: Sendable {
    func load() -> SubscriptionSnapshot?
    func save(_ snapshot: SubscriptionSnapshot)
}
