//
//  CancellationPolicy.swift
//  BelloHub
//

import Foundation

/// The professional's cancellation and change rules, read by clients before they book (D11). The values produce
/// the client-facing text in every language, so the app and the booking page can never disagree.
struct CancellationPolicy: Hashable, Codable, Sendable {
    /// Hours before the visit up to which changes are free: 2, 12, 24, 48 or 72.
    var freeWindowHours: Int
    var clientCanReschedule: Bool
    /// How many times one visit may be moved by the client. Nil means no limit.
    var maxReschedules: Int?
    var afterWindowCancel: AfterWindowCancel
    var afterWindowReschedule: AfterWindowReschedule
    /// The reminder asks the client to confirm she is coming.
    var askConfirmation: Bool
    /// How long she holds the time when a client is late: 5 to 20 minutes.
    var graceMinutes: Int

    static let freeWindowOptions = [2, 12, 24, 48, 72]
    static let graceRange = 5...20

    /// The defaults of the prototype: free changes up to 24 hours, reschedule up to 2 times, cancelling after
    /// that is allowed with an honest warning, 15 minutes of grace.
    static let standard = CancellationPolicy(
        freeWindowHours: 24,
        clientCanReschedule: true,
        maxReschedules: 2,
        afterWindowCancel: .allow,
        afterWindowReschedule: .request,
        askConfirmation: false,
        graceMinutes: 15
    )
}
