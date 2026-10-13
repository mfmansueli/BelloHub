//
//  ClientLinkService.swift
//  BelloHub
//

import Foundation
import Observation

/// Gives a message about a visit its link: the client's own link to change or cancel when the server can mint one
/// (`mintManageLink`, API.md 6.3), otherwise her booking page, and says which (`ClientLinkChoice`). Read with
/// `@Environment(ClientLinkService.self)`; one per signed-in session, created with the inbox Services.
///
/// A minted link is kept in memory for `ClientLinkPlan.reuseInterval`, so opening the sheet again does not ask the
/// server twice. Never persisted and never logged: the link opens the client's booking.
@MainActor
@Observable
final class ClientLinkService {
    @ObservationIgnored private let repository: any InboxRepository
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var minted: [String: (link: ClientManageLink, fetchedAt: Date)] = [:]

    init(repository: any InboxRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    // MARK: - Links

    /// The link a message about `appointment` carries. Falls back to `bookingPage` when the visit was added by hand, is
    /// no longer active, the iPhone is offline or the server did not answer; never throws.
    func choice(for appointment: Appointment, bookingPage: BookingLink?) async -> ClientLinkChoice {
        let page = bookingPage?.messageText
        switch ClientLinkPlan.request(for: appointment, now: now()) {
        case .bookingPage(let reason):
            return ClientLinkChoice(source: .bookingPage(reason), link: page)
        case .manageLink(let bookingID):
            if let kept = minted[bookingID], ClientLinkPlan.canReuse(kept.link, fetchedAt: kept.fetchedAt, now: now()) {
                return ClientLinkChoice(source: .manageLink, link: ClientLinkText.text(kept.link.url))
            }
            do {
                let link = try await repository.mintManageLink(bookingId: bookingID)
                minted[bookingID] = (link, now())
                return ClientLinkChoice(source: .manageLink, link: ClientLinkText.text(link.url))
            } catch {
                return ClientLinkChoice(source: .bookingPage(Self.reason(for: error)), link: page)
            }
        }
    }

    /// Forgets every minted link (lock, sign-out).
    func clear() {
        minted = [:]
    }

    /// Registers an appointment scheduled by hand, obtaining the client's exclusive manage link (/m/<token>).
    func registerManualBooking(
        appointment: Appointment,
        client: Client,
        serviceName: String,
        timeZoneID: String,
        locale: String?
    ) async -> ClientManageLink? {
        do {
            let bookingID = appointment.id.uuidString.lowercased()
            let registration = ManualBookingRegistration(
                appointmentId: bookingID,
                serviceName: serviceName,
                startsAt: appointment.startsAt,
                endsAt: appointment.endsAt,
                timeZoneID: timeZoneID,
                client: .init(
                    name: client.name,
                    phone: client.phoneE164 ?? "",
                    email: client.email,
                    locale: locale
                )
            )
            let link = try await repository.registerManualBooking(registration)
            minted[bookingID] = (link, now())
            return link
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static func reason(for error: any Error) -> ClientLinkChoice.Reason {
        switch error as? BookingRepositoryError {
        case .unreachable?, .notPublishedYet?: .offline
        default: .failed
        }
    }
}
