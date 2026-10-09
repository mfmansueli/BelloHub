//
//  InboxTestFactories.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A booking from the server, `daysAhead` days after `TestClock.now` at `hour` in São Paulo.
func makeIncomingBooking(
    id: String = "bk-1", status: IncomingBookingStatus = .pendingApproval, reason: PendingReason? = .newClient,
    daysAhead: Int = 2, hour: Int = 10, minutes: Int = 90, clientName: String = "Ana Costa",
    phone: String = "+5511981234410", policy: CancellationPolicy? = .standard
) -> IncomingBooking {
    let start = TestClock.now.addingTimeInterval(TimeInterval(daysAhead * 86_400 + (hour - 12) * 3_600))
    return IncomingBooking(
        id: id, status: status, pendingReason: status == .pendingApproval ? reason : nil, serviceId: "svc-glow",
        serviceName: "Brazilian Glow", durationMinutes: minutes, startsAt: start,
        endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), timeZoneID: "America/Sao_Paulo",
        client: .init(name: clientName, phone: phone, email: nil, locale: "pt-BR"), note: "See you then",
        policy: policy, createdAt: TestClock.now.addingTimeInterval(-3_600)
    )
}

/// A request to move `bookingID`, asked `hoursBefore` hours before the current visit.
func makeRescheduleRequest(
    id: String = "rr-1", bookingID: String = "bk-1", currentStart: Date = TestClock.now.addingTimeInterval(86_400),
    hoursBefore: Double = 19, status: RescheduleRequest.Status = .pending
) -> RescheduleRequest {
    RescheduleRequest(
        id: id, bookingId: bookingID, clientName: "Camila Rocha", serviceName: "Glow Facial",
        currentStart: currentStart, currentEnd: currentStart.addingTimeInterval(3_600),
        requestedStart: currentStart.addingTimeInterval(86_400 + 3_600),
        requestedEnd: currentStart.addingTimeInterval(86_400 + 7_200), note: "Something came up", status: status,
        createdAt: currentStart.addingTimeInterval(-hoursBefore * 3_600)
    )
}

/// Somebody waiting from `from` to `until` (`yyyy-MM-dd`), who asked `daysAgo` days before `TestClock.now`.
func makeWaitlistRequest(
    id: String, from: String = "2026-10-01", until: String = "2026-10-08", daysAgo: Int = 3,
    status: WaitlistRequest.Status = .waiting
) -> WaitlistRequest {
    WaitlistRequest(
        id: id, name: "Person \(id)", phone: "+55119000\(id.count)", serviceId: "svc-glow", serviceName: "Glow Facial",
        dayFrom: from, dayTo: until, status: status,
        createdAt: TestClock.now.addingTimeInterval(TimeInterval(-daysAgo * 86_400))
    )
}
