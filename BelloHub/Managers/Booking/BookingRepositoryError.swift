//
//  BookingRepositoryError.swift
//  BelloHub
//

/// What the booking server connection can refuse.
enum BookingRepositoryError: Error, Equatable, Sendable {
    /// The app is not connected to the booking server yet (S8), so nothing can be published or checked. Not a failure
    /// of her network: the screens show "once you go online" instead of an error.
    case notPublishedYet
    /// The server could not be reached or answered with an error.
    case unreachable
}
