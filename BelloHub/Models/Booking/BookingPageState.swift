//
//  BookingPageState.swift
//  BelloHub
//

import Foundation

/// Whether her booking page takes bookings right now (`BookingPause.state`).
enum BookingPageState: Equatable, Sendable {
    case accepting
    /// Paused, with the day it opens again when she gave one.
    case paused(until: Date?)
}
