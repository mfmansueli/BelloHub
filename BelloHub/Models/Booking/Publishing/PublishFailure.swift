//
//  PublishFailure.swift
//  BelloHub
//

/// Why her page is not (fully) online, in terms the screen can say honestly. `isRetryable` says whether trying again
/// later can help without her changing something.
enum PublishFailure: Equatable, Sendable {
    /// She has not chosen an address yet.
    case needsAddress
    /// A page needs at least one service clients can book.
    case needsService
    /// Somebody else owns the address she chose.
    case addressTaken
    /// The phone cannot reach the server now; the page is as it was and the change goes out when it can.
    case offline
    /// The server is busy or limited the calls; the app tries again by itself.
    case busy
    /// Signed out of the server (token refused): sign in again.
    case signedOut
    /// The vault is locked, so the page cannot be built.
    case locked
    /// The server refused what the app sent, or answered something unreadable. Not fixed by waiting.
    case rejected
    /// The page serves an inbox key this iPhone did not derive, even after publishing again (docs/06 section 3.2):
    /// publishing stops until she retries, and she is told to contact support.
    case keyMismatch

    var isRetryable: Bool {
        switch self {
        case .offline, .busy, .locked: true
        case .needsAddress, .needsService, .addressTaken, .signedOut, .rejected, .keyMismatch: false
        }
    }
}
