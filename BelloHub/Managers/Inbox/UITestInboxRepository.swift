//
//  UITestInboxRepository.swift
//  BelloHub
//

#if DEBUG
import CryptoKit
import Foundation

/// An in-memory inbox server for UI tests (`-uiInbox fixtures`): a booking request from Ana (no-show limit), a new
/// booking from Helena, a reschedule request from Camila, three people on the waitlist, and one sealed health form for
/// Helena, sealed at first read to the test key (`InMemoryKeyStore` seed), so the whole open-and-import path runs on
/// the simulator. Answers change the data like the server would. DEBUG only.
///
/// `-uiInbox paywall` makes the approval answer `needsSubscription` (D42).
@MainActor
final class UITestInboxRepository: InboxRepository {
    enum Scenario: String {
        case fixtures
        case paywall
    }

    static let requestID = "req-ana"
    static let helenaBookingID = "bk-helena"
    static let camilaBookingID = "bk-camila"
    static let rescheduleID = "rr-camila"
    static let intakeItemID = "7f0f4c6e-1c2b-4d6a-9a1e-000000000001"
    static let glowServiceID = "11111111-1111-4111-8111-111111111111"

    private let scenario: Scenario
    private let publicKey: @MainActor () throws -> Curve25519.KeyAgreement.PublicKey
    private let now: Date
    private var bookings: [IncomingBooking]
    private var requests: [RescheduleRequest]
    private var waitlist: [WaitlistRequest]
    private var items: [MailboxItem] = []
    private var sealed = false
    private(set) var acknowledged: [String] = []
    private(set) var devices: [String] = []

    init(scenario: Scenario, publicKey: @escaping @MainActor () throws -> Curve25519.KeyAgreement.PublicKey, now: Date = Date()) {
        self.scenario = scenario
        self.publicKey = publicKey
        self.now = now
        let zone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        func at(days: Int, hour: Int, minutes: Int = 0) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let day = calendar.startOfDay(for: now.addingTimeInterval(TimeInterval(days * 86_400)))
            return calendar.date(bySettingHour: hour, minute: minutes, second: 0, of: day) ?? day
        }
        let policy = CancellationPolicy.standard
        bookings = [
            IncomingBooking(
                id: Self.requestID, status: .pendingApproval, pendingReason: .noShowLimit,
                serviceId: Self.glowServiceID, serviceName: "Brazilian Glow", durationMinutes: 90,
                startsAt: at(days: 6, hour: 10), endsAt: at(days: 6, hour: 11, minutes: 30),
                timeZoneID: zone.identifier,
                client: .init(name: "Ana Costa", phone: "+5511981234410", email: nil, locale: "pt-BR"),
                note: "Hi Maria! I can make it this time. I set two reminders.", policy: policy,
                noShowPolicy: .init(isOn: true, limit: 2, lateCancelCounts: true),
                createdAt: now.addingTimeInterval(-1_800)
            ),
            IncomingBooking(
                id: Self.helenaBookingID, status: .confirmed, serviceId: Self.glowServiceID, serviceName: "Glow Facial",
                durationMinutes: 60, startsAt: at(days: 3, hour: 14), endsAt: at(days: 3, hour: 15),
                timeZoneID: zone.identifier,
                client: .init(name: "Helena Duarte", phone: "+5511977770001", email: "helena@example.com", locale: "pt-BR"),
                policy: policy, createdAt: now.addingTimeInterval(-3_600)
            ),
            IncomingBooking(
                id: Self.camilaBookingID, status: .confirmed, serviceId: Self.glowServiceID, serviceName: "Glow Facial",
                durationMinutes: 60, startsAt: at(days: 2, hour: 10), endsAt: at(days: 2, hour: 11),
                timeZoneID: zone.identifier,
                client: .init(name: "Camila Rocha", phone: "+5511977770002", email: nil, locale: "pt-BR"),
                policy: policy, createdAt: now.addingTimeInterval(-7 * 86_400)
            )
        ]
        requests = [
            RescheduleRequest(
                id: Self.rescheduleID, bookingId: Self.camilaBookingID, clientName: "Camila Rocha",
                serviceName: "Glow Facial", currentStart: at(days: 2, hour: 10), currentEnd: at(days: 2, hour: 11),
                requestedStart: at(days: 3, hour: 11), requestedEnd: at(days: 3, hour: 12),
                note: "Hi Maria, something came up at work. Could we do Saturday instead? Sorry for the short notice!",
                createdAt: now.addingTimeInterval(-900)
            )
        ]
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        let from = formatter.string(from: now)
        let until = formatter.string(from: now.addingTimeInterval(7 * 86_400))
        waitlist = [
            WaitlistRequest(
                id: "wl-paula", name: "Paula Nunes", phone: "+5511977770003", serviceId: Self.glowServiceID,
                serviceName: "Glow Facial", dayFrom: from, dayTo: until, createdAt: now.addingTimeInterval(-6 * 86_400)
            ),
            WaitlistRequest(
                id: "wl-marina", name: "Marina Alves", phone: "+5511977770004", serviceName: "Deep Cleansing",
                dayFrom: from, dayTo: until, createdAt: now.addingTimeInterval(-4 * 86_400)
            ),
            WaitlistRequest(
                id: "wl-beatriz", name: "Beatriz Lima", phone: "+5511977770005", serviceId: Self.glowServiceID,
                serviceName: "Glow Facial", dayFrom: from, dayTo: until, createdAt: now.addingTimeInterval(-2 * 86_400)
            )
        ]
    }

    // MARK: - Reads

    func bookings(uid: String, since: Date) async throws -> [IncomingBooking] {
        bookings.filter { $0.startsAt >= since }
    }

    func rescheduleRequests(uid: String) async throws -> [RescheduleRequest] { requests }

    func waitlist(uid: String) async throws -> [WaitlistRequest] { waitlist }

    func mailboxItems(uid: String) async throws -> [MailboxItem] {
        if !sealed {
            sealed = true
            let payload: [String: Any] = [
                "schema": 2, "bookingId": Self.helenaBookingID, "localeId": "pt-BR", "formVersion": "1",
                "answers": [
                    "allergies": ["fragrance", "latex"], "medication": false, "pregnantOrBreastfeeding": false,
                    "skinCondition": true, "anythingElse": "Sensitive to fragrances; had a peel two weeks ago."
                ],
                "isForMinor": false, "submittedAt": CallableJSON.instant(now.addingTimeInterval(-600)), "_pad": ""
            ]
            if let key = try? publicKey(), let plaintext = try? JSONSerialization.data(withJSONObject: payload),
               let envelope = try? EnvelopeOpener.seal(plaintext, to: key, kind: .intake, itemId: Self.intakeItemID) {
                items.append(MailboxItem(
                    id: Self.intakeItemID, kind: .intake, bookingId: Self.helenaBookingID, keyId: envelope.keyId,
                    sizeBytes: plaintext.count, createdAt: now.addingTimeInterval(-600), envelope: envelope
                ))
            }
        }
        return items
    }

    func mailboxItem(id: String) async throws -> MailboxItem {
        guard let item = items.first(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        return item
    }

    // MARK: - Writes

    func respondBookingRequest(id: String, approve: Bool) async throws -> BookingRequestOutcome {
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        if approve, scenario == .paywall { return .needsSubscription }
        bookings[index].status = approve ? .confirmed : .declined
        bookings[index].pendingReason = nil
        bookings[index].updatedAt = Date()
        return approve ? .confirmed : .declined
    }

    func respondRescheduleRequest(id: String, accept: Bool) async throws -> RescheduleOutcome {
        guard let index = requests.firstIndex(where: { $0.id == id }) else { throw BookingRepositoryError.rejected }
        requests[index].status = accept ? .accepted : .declined
        if accept, let booking = bookings.firstIndex(where: { $0.id == requests[index].bookingId }) {
            bookings[booking].startsAt = requests[index].requestedStart
            bookings[booking].endsAt = requests[index].requestedEnd
            bookings[booking].rescheduleCount += 1
            bookings[booking].updatedAt = Date()
        }
        return accept ? .accepted : .declined
    }

    func offerWaitlistSlot(_ offer: WaitlistOffer) async throws -> WaitlistOfferOutcome {
        guard let index = waitlist.firstIndex(where: { $0.id == offer.waitlistId }) else {
            throw BookingRepositoryError.rejected
        }
        waitlist[index].status = .offered
        waitlist[index].offeredAt = Date()
        return .offered(holdKey: "offer-\(offer.waitlistId)", expiresAt: Date().addingTimeInterval(3 * 3_600))
    }

    func removeWaitlistEntry(id: String) async throws {
        waitlist.removeAll { $0.id == id }
    }

    func resetNoShowCount(phone: String) async throws {}

    func acknowledgeMailboxItem(id: String) async throws {
        acknowledged.append(id)
        items.removeAll { $0.id == id }
    }

    func registerDevice(fcmToken: String, locale: String?) async throws {
        devices.append(fcmToken)
    }

    func unregisterDevice(fcmToken: String) async throws {
        devices.removeAll { $0 == fcmToken }
    }
}
#endif
