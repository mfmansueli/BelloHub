//
//  SyncStatus.swift
//  BelloHub
//

import Foundation

/// Where the vault's iCloud sync stands, for the small status pill and the `States` screen (docs/03-BUILD-PLAN.md S2).
enum SyncStatus: Equatable, Sendable {
    /// Sync is not switched on (CloudKit is off until the schema is deployed, H2): everything stays on this phone.
    case localOnly
    /// Everything is up to date as of this moment, if known.
    case synced(Date?)
    case syncing
    /// No network. Changes are saved on the phone and sync when it is back.
    case offline
    /// Not signed in to iCloud, or iCloud Drive is off for the app.
    case iCloudUnavailable
    /// The professional's iCloud storage is full; photos are the usual cause (docs/02-DECISIONS.md, risk 3).
    case iCloudFull
    case error
}
