//
//  LocationVisibility.swift
//  BelloHub
//

import Foundation

/// Where the address of the place she works shows (owner, 2026-10-11). Many professionals work from home, so the
/// default keeps it to people who already have a confirmed booking.
enum LocationVisibility: String, PersistedEnum, Identifiable {
    /// Confirmation e-mail and page, the personal link's page, the calendar file and her messages (`{address}`).
    case confirmedClients
    /// Also on the public booking page, for anyone who opens it.
    case bookingPage

    /// An unknown value shows less, never more.
    static let fallback = LocationVisibility.confirmedClients

    var id: String { rawValue }

    /// What the server calls it (`location.visibility`, API.md 6.2).
    var wireValue: String {
        switch self {
        case .confirmedClients: "confirmed"
        case .bookingPage: "public"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .confirmedClients:
            LocalizedStringResource(
                "workplace.visibility.confirmed", defaultValue: "Only clients with a confirmed booking"
            )
        case .bookingPage:
            LocalizedStringResource("workplace.visibility.public", defaultValue: "Also on my booking page")
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .confirmedClients: LocalizedStringResource("workplace.visibility.confirmed.detail")
        case .bookingPage: LocalizedStringResource("workplace.visibility.public.detail")
        }
    }
}
