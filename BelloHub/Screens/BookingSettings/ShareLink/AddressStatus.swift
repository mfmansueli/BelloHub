//
//  AddressStatus.swift
//  BelloHub
//

/// What the address field says about the text in it.
enum AddressStatus: Equatable, Sendable {
    /// Nothing typed yet, or nothing to report.
    case idle
    /// The server is being asked.
    case checking
    case available
    case taken
    /// A word nobody may own, as the server said it.
    case reserved
    /// The text breaks a rule the app knows (`BookingSlug`), so the server is not asked.
    case invalid(SlugIssue)
    /// The server is not connected yet (S8): the address is valid but cannot be checked.
    case unchecked
}
