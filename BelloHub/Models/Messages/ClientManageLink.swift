//
//  ClientManageLink.swift
//  BelloHub
//

import Foundation

/// A client's own link to change or cancel one booking (`https://bellohub.app/m/<token>`), minted by the server for a
/// message she sends (`mintManageLink`, API.md 6.3). The app cannot build it: the server keeps only token hashes.
struct ClientManageLink: Equatable, Sendable {
    let url: URL
    /// When the link stops opening the booking (the visit's end plus seven days).
    let expiresAt: Date
}
