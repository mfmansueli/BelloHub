//
//  WaitlistOfferOutcome.swift
//  BelloHub
//

import Foundation

/// What the server answers to a `WaitlistOffer`.
enum WaitlistOfferOutcome: Equatable, Sendable {
    /// The link is `<web>/<slug>/time?offer=<holdKey>`.
    case offered(holdKey: String, expiresAt: Date)
    /// The time is not free by her own rules.
    case slotTaken
}
