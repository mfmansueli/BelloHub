//
//  PublishStatusText.swift
//  BelloHub
//

import Foundation

/// What the booking screens say about the state of her page, in one place so the More row, the link card and Share your
/// link never disagree (CLAUDE.md section 9, point 6). Pure: the Views only format the resources it returns.
enum PublishStatusText {
    /// The line under the More row: the page summary once the page is live, "Not online yet" before, "Needs attention"
    /// when the last publish failed and no page exists yet.
    static func rowSubtitle(_ state: PublishState, pageSummary: LocalizedStringResource) -> LocalizedStringResource {
        switch state {
        case .notOnline, .publishing(wasOnline: false):
            LocalizedStringResource("publish.row.notOnline", defaultValue: "Not online yet")
        case .error(_, wasOnline: false):
            LocalizedStringResource("publish.row.attention", defaultValue: "Needs attention")
        case .online, .paused, .publishing(wasOnline: true), .error(_, wasOnline: true):
            pageSummary
        }
    }

    /// The status line on the link card and under the QR code: what clients will find at the link.
    static func linkStatus(_ state: PublishState) -> LocalizedStringResource {
        switch state {
        case .online:
            LocalizedStringResource(
                "publish.status.online", defaultValue: "Online. Clients can book you with this link."
            )
        case .paused:
            LocalizedStringResource("publish.status.paused", defaultValue: "Online, not taking bookings right now.")
        case .publishing:
            LocalizedStringResource("publish.status.publishing", defaultValue: "Updating your page…")
        case .notOnline, .error(_, wasOnline: false):
            LocalizedStringResource(
                "bookingSettings.link.notOnline", defaultValue: "Preview only. The link works once you go online."
            )
        case .error(_, wasOnline: true):
            LocalizedStringResource(
                "publish.status.stale", defaultValue: "Online, but your latest changes are not on the page yet."
            )
        }
    }

    /// The sentence for a failure; it says whether the page that is already online keeps working.
    static func failure(_ failure: PublishFailure, wasOnline: Bool) -> LocalizedStringResource {
        switch failure {
        case .needsAddress:
            LocalizedStringResource("publish.error.needsAddress", defaultValue: "Choose your address first.")
        case .needsService:
            LocalizedStringResource(
                "publish.error.needsService", defaultValue: "Add at least one active service to put your page online."
            )
        case .addressTaken:
            LocalizedStringResource(
                "publish.error.addressTaken", defaultValue: "That address is taken. Choose another one."
            )
        case .signedOut:
            LocalizedStringResource("publish.error.signedOut", defaultValue: "Sign in again to publish your page.")
        case .locked:
            LocalizedStringResource("publish.error.locked", defaultValue: "Unlock Bello Hub to publish your page.")
        case .busy:
            LocalizedStringResource(
                "publish.error.busy", defaultValue: "The server is busy. We will try again in a moment."
            )
        case .offline:
            offline(wasOnline: wasOnline)
        case .keyMismatch:
            LocalizedStringResource(
                "publish.error.keyMismatch",
                defaultValue: """
                Your booking page shows a form key that is not the one on this iPhone, so publishing is stopped. \
                Try again; if this message comes back, contact support.
                """
            )
        case .rejected:
            LocalizedStringResource(
                "publish.error.rejected",
                defaultValue: "Your page could not be published. Check your details and try again."
            )
        }
    }

    private static func offline(wasOnline: Bool) -> LocalizedStringResource {
        if wasOnline {
            return LocalizedStringResource(
                "publish.error.offlineLive",
                defaultValue: """
                No connection. Your page is online, but your latest changes are not on it yet. \
                We will send them when you are connected.
                """
            )
        }
        return LocalizedStringResource(
            "publish.error.offline",
            defaultValue: "No connection. Your page is not online yet. Try again when you are connected."
        )
    }

    /// Whether the failure line offers "Try again": it does unless she has to change something first (an address, a
    /// service) or sign in again.
    static func offersRetry(_ failure: PublishFailure) -> Bool {
        switch failure {
        case .needsAddress, .needsService, .addressTaken, .signedOut: false
        case .offline, .busy, .locked, .rejected, .keyMismatch: true
        }
    }
}
