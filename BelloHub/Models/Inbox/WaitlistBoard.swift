//
//  WaitlistBoard.swift
//  BelloHub
//

import Foundation

/// What the waitlist (2.9) shows, worked out from the inbox snapshot: the time that opened up (the next visit a client
/// or she cancelled that nobody has taken since), the people waiting for that day, and everybody else still waiting.
/// Pure, so the Alerts tab and the waitlist screen read the same answer; it takes `now`.
struct WaitlistBoard: Equatable, Sendable {
    /// A cancelled visit whose time is free again.
    struct OpenTime: Equatable, Sendable {
        let bookingID: String
        let serviceID: String
        let serviceName: String
        let clientName: String
        let startsAt: Date
        let endsAt: Date

        var minutes: Int { max(Int(endsAt.timeIntervalSince(startsAt) / 60), 0) }
    }

    let openTime: OpenTime?
    /// Waiting (or already offered) for the day of `openTime`, oldest request first.
    let forThatDay: [WaitlistRequest]
    /// Everybody else still waiting, oldest first.
    let others: [WaitlistRequest]

    var isEmpty: Bool { forThatDay.isEmpty && others.isEmpty }

    /// The people "Offer to everyone" reaches: waiting for that day and not offered yet.
    var offerable: [WaitlistRequest] { forThatDay.filter(\.isWaiting) }

    static func make(snapshot: InboxSnapshot, timeZone: TimeZone, now: Date) -> WaitlistBoard {
        let open = openTime(in: snapshot.bookings, now: now)
        let listed = snapshot.waitlist
            .filter { $0.status != .booked }
            .sorted { $0.createdAt < $1.createdAt }
        guard let open else {
            return WaitlistBoard(openTime: nil, forThatDay: [], others: listed.filter(\.isWaiting))
        }
        let day = dayKey(open.startsAt, timeZone: timeZone)
        let forThatDay = listed.filter { $0.covers(day: day) }
        let others = listed.filter { !$0.covers(day: day) && $0.isWaiting }
        return WaitlistBoard(openTime: open, forThatDay: forThatDay, others: others)
    }

    /// The earliest future cancellation whose time no confirmed booking has taken since.
    static func openTime(in bookings: [IncomingBooking], now: Date) -> OpenTime? {
        let taken = bookings.filter { $0.status.holdsTime }
        return bookings
            .filter { [.cancelledByClient, .cancelledByPro].contains($0.status) && $0.startsAt > now }
            .filter { cancelled in
                !taken.contains { $0.startsAt < cancelled.endsAt && cancelled.startsAt < $0.endsAt }
            }
            .min { $0.startsAt < $1.startsAt }
            .map {
                OpenTime(
                    bookingID: $0.id, serviceID: $0.serviceId, serviceName: $0.serviceName, clientName: $0.client.name,
                    startsAt: $0.startsAt, endsAt: $0.endsAt
                )
            }
    }

    /// `yyyy-MM-dd` in the business time zone: the form the server writes `dayFrom` / `dayTo` in.
    static func dayKey(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
