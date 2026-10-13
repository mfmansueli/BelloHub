//
//  BookingRepositoryError.swift
//  BelloHub
//

/// What the booking server connection can refuse, in the app's own words (`RemoteBookingRepository` maps `ServerError`
/// to these, so nothing above it knows a code or a status).
enum BookingRepositoryError: Error, Equatable, Sendable {
    /// The app is not connected to the booking server (a build without one), so nothing can be published or checked.
    /// Not a failure of her network: the screens show "once you go online" instead of an error.
    case notPublishedYet
    /// The phone could not reach the server. Nothing is lost: the same call works when the network is back.
    case unreachable
    /// The server is busy or limited the calls. Worth trying again in a while.
    case busy
    /// The token was refused or nobody is signed in: she has to sign in again.
    case unauthenticated
    /// Somebody else owns the address.
    case slugTaken
    /// The server does not accept the address (it breaks a rule the app should have caught).
    case slugInvalid
    /// Another visit or block already occupies this time.
    case conflict
    /// The server refused the content, or answered something the app cannot read. Retrying does not help.
    case rejected
}
