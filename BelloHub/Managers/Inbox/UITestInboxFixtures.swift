//
//  UITestInboxFixtures.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// The data `UITestInboxRepository` starts with, relative to `now` in the seeded business time zone: a booking
/// request from Ana (no-show limit), a new booking from Helena, Camila's booking with a reschedule request, a visit
/// Júlia cancelled (the time that opened up) and three people waiting for that week. DEBUG only.
enum UITestInboxFixtures {
    static let requestID = "req-ana"
    static let helenaBookingID = "bk-helena"
    static let camilaBookingID = "bk-camila"
    static let rescheduleID = "rr-camila"
    static let cancelledBookingID = "bk-julia"
    static let intakeItemID = "7f0f4c6e-1c2b-4d6a-9a1e-000000000001"
    static let glowServiceID = "11111111-1111-4111-8111-111111111111"
    static let zone = TimeZone(identifier: "America/Sao_Paulo") ?? .current

    static func bookings(now: Date) -> [IncomingBooking] {
        let policy = CancellationPolicy.standard
        return [
            IncomingBooking(
                id: requestID, status: .pendingApproval, pendingReason: .noShowLimit,
                serviceId: glowServiceID, serviceName: "Brazilian Glow", durationMinutes: 90,
                startsAt: at(days: 6, hour: 10, now: now), endsAt: at(days: 6, hour: 11, minutes: 30, now: now),
                timeZoneID: zone.identifier,
                client: .init(name: "Ana Costa", phone: "+5511981234410", email: nil, locale: "pt-BR"),
                note: "Hi Maria! I can make it this time. I set two reminders.", policy: policy,
                noShowPolicy: .init(isOn: true, limit: 2, lateCancelCounts: true),
                createdAt: now.addingTimeInterval(-1_800)
            ),
            IncomingBooking(
                id: helenaBookingID, status: .confirmed, serviceId: glowServiceID, serviceName: "Glow Facial",
                durationMinutes: 60, startsAt: at(days: 3, hour: 14, now: now), endsAt: at(days: 3, hour: 15, now: now),
                timeZoneID: zone.identifier,
                client: .init(
                    name: "Helena Duarte", phone: "+5511977770001", email: "helena@example.com", locale: "pt-BR"
                ),
                policy: policy, createdAt: now.addingTimeInterval(-3_600)
            ),
            IncomingBooking(
                id: camilaBookingID, status: .confirmed, serviceId: glowServiceID, serviceName: "Glow Facial",
                durationMinutes: 60, startsAt: at(days: 2, hour: 10, now: now), endsAt: at(days: 2, hour: 11, now: now),
                timeZoneID: zone.identifier,
                client: .init(name: "Camila Rocha", phone: "+5511977770002", email: nil, locale: "pt-BR"),
                policy: policy, createdAt: now.addingTimeInterval(-7 * 86_400)
            ),
            IncomingBooking(
                id: cancelledBookingID, status: .cancelledByClient, serviceId: glowServiceID,
                serviceName: "Brazilian Glow", durationMinutes: 90, startsAt: at(days: 4, hour: 15, now: now),
                endsAt: at(days: 4, hour: 16, minutes: 30, now: now), timeZoneID: zone.identifier,
                client: .init(name: "Júlia Mendes", phone: "+5511977770006", email: nil, locale: "pt-BR"),
                policy: policy, cancelledAt: now.addingTimeInterval(-1_200), cancelledBy: "client",
                createdAt: now.addingTimeInterval(-10 * 86_400), updatedAt: now.addingTimeInterval(-1_200)
            )
        ]
    }

    static func requests(now: Date) -> [RescheduleRequest] {
        [
            RescheduleRequest(
                id: rescheduleID, bookingId: camilaBookingID, clientName: "Camila Rocha", serviceName: "Glow Facial",
                currentStart: at(days: 2, hour: 10, now: now), currentEnd: at(days: 2, hour: 11, now: now),
                requestedStart: at(days: 3, hour: 11, now: now), requestedEnd: at(days: 3, hour: 12, now: now),
                note: "Hi Maria, something came up at work. Could we do Saturday instead? Sorry for the short notice!",
                createdAt: now.addingTimeInterval(-900)
            )
        ]
    }

    static func waitlist(now: Date) -> [WaitlistRequest] {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        let from = formatter.string(from: now)
        let until = formatter.string(from: now.addingTimeInterval(7 * 86_400))
        return [
            WaitlistRequest(
                id: "wl-paula", name: "Paula Nunes", phone: "+5511977770003", serviceId: glowServiceID,
                serviceName: "Glow Facial", dayFrom: from, dayTo: until, createdAt: now.addingTimeInterval(-6 * 86_400)
            ),
            WaitlistRequest(
                id: "wl-marina", name: "Marina Alves", phone: "+5511977770004", serviceName: "Deep Cleansing",
                dayFrom: from, dayTo: until, createdAt: now.addingTimeInterval(-4 * 86_400)
            ),
            WaitlistRequest(
                id: "wl-beatriz", name: "Beatriz Lima", phone: "+5511977770005", serviceId: glowServiceID,
                serviceName: "Glow Facial", dayFrom: from, dayTo: until, createdAt: now.addingTimeInterval(-2 * 86_400)
            )
        ]
    }

    /// Helena's health form, schema 2, as the page would seal it.
    static func intakePlaintext(now: Date) -> Data {
        let payload: [String: Any] = [
            "schema": 2, "bookingId": helenaBookingID, "localeId": "pt-BR", "formVersion": "1",
            "answers": [
                "allergies": ["fragrance", "latex"], "medication": false, "pregnantOrBreastfeeding": false,
                "skinCondition": true, "anythingElse": "Sensitive to fragrances; had a peel two weeks ago."
            ],
            "isForMinor": false, "submittedAt": CallableJSON.instant(now.addingTimeInterval(-600)), "_pad": ""
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    private static func at(days: Int, hour: Int, minutes: Int = 0, now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.startOfDay(for: now.addingTimeInterval(TimeInterval(days * 86_400)))
        return calendar.date(bySettingHour: hour, minute: minutes, second: 0, of: day) ?? day
    }
}
#endif
