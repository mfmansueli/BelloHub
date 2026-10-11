//
//  FirestoreSince.swift
//  BelloHub
//

import Foundation

/// A lower bound on a timestamp field for `FirestoreClient.query` (the composite index of `bookings` is
/// `ownerUid, startsAt`, so the bound and the order use the same field).
struct FirestoreSince: Equatable, Sendable {
    let field: String
    let date: Date
}
