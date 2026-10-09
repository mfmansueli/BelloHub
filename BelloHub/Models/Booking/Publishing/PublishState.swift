//
//  PublishState.swift
//  BelloHub
//

import Foundation

/// Where her booking page stands for the screens (More row, Booking page, Share your link).
enum PublishState: Equatable, Sendable {
    /// Not published (never gone online, or stopped). The link is only a preview.
    case notOnline
    /// A publish is running; `wasOnline` says the page already exists (a republish after a change), so the link keeps
    /// working while it runs.
    case publishing(wasOnline: Bool)
    /// Published and taking bookings.
    case online
    /// Published, but not taking bookings now (her pause), with the day it opens again when she gave one.
    case paused(until: Date?)
    /// The last publish failed. `wasOnline` says whether a page already exists on the server (and so the link works,
    /// just without her latest changes).
    case error(PublishFailure, wasOnline: Bool)

    /// The link works for clients: the page exists on the server.
    var isLive: Bool {
        switch self {
        case .online, .paused: true
        case .error(_, let wasOnline), .publishing(let wasOnline): wasOnline
        case .notOnline: false
        }
    }
}
