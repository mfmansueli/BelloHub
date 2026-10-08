//
//  SyncFailure.swift
//  BelloHub
//

/// Why a sync step failed, in terms of what the professional can do about it.
enum SyncFailure: Equatable, Sendable {
    case notSignedIn
    case quotaExceeded
    case networkUnavailable
    case other
}
