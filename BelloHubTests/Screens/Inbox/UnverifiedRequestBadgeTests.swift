//
//  UnverifiedRequestBadgeTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// A booking request as the server sends it when the client confirmed on WhatsApp (no e-mail code, API.md 5.8).
private func makeUnverified(
    status: IncomingBookingStatus = .pendingApproval, reason: PendingReason? = nil, reference: String? = "K7M2P"
) -> IncomingBooking {
    var booking = makeIncomingBooking(status: status, reason: reason)
    booking.pendingReason = status == .pendingApproval ? reason : nil
    booking.verification = "whatsapp"
    booking.reference = reference
    booking.pendingExpiresAt = TestClock.now.addingTimeInterval(22 * 3_600)
    return booking
}

@Suite("UnverifiedRequestBadge")
struct UnverifiedRequestBadgeTests {
    @Test("A waiting request made on WhatsApp gets the badge with its reference, phone and release time")
    func badgeForAWaitingUnverifiedRequest() {
        let badge = UnverifiedRequestBadge.make(for: makeUnverified())

        #expect(badge == UnverifiedRequestBadge(
            reference: "K7M2P", phone: "+5511981234410", releasedAt: TestClock.now.addingTimeInterval(22 * 3_600)
        ))
    }

    @Test("A verified request, or an unverified one already answered, has no badge")
    func noBadge() {
        #expect(UnverifiedRequestBadge.make(for: makeIncomingBooking()) == nil)
        #expect(UnverifiedRequestBadge.make(for: makeUnverified(status: .confirmed)) == nil)
        #expect(UnverifiedRequestBadge.make(for: makeUnverified(status: .declined)) == nil)
        var other = makeUnverified()
        other.verification = "somethingNew"
        #expect(UnverifiedRequestBadge.make(for: other) == nil, "only the known flag means unverified")
    }

    @Test("The reference is shown upper-cased, and dropped when it is not one the server makes")
    func referenceShape() {
        #expect(UnverifiedRequestBadge.normalizedReference(" k7m2p ") == "K7M2P")
        #expect(UnverifiedRequestBadge.normalizedReference("K7M2") == nil)
        #expect(UnverifiedRequestBadge.normalizedReference("K0M2P") == nil, "0 is not in the alphabet")
        #expect(UnverifiedRequestBadge.normalizedReference("KIM2P") == nil, "I is not in the alphabet")
        #expect(UnverifiedRequestBadge.make(for: makeUnverified(reference: "<b>")) != nil)
        #expect(UnverifiedRequestBadge.make(for: makeUnverified(reference: "<b>"))?.reference == nil)
        #expect(UnverifiedRequestBadge.make(for: makeUnverified(reference: nil))?.reference == nil)
    }

    @Test("The reason notice shows only when the server gave one: the badge replaces the new-client guess")
    func reasonVisibility() {
        #expect(!UnverifiedRequestBadge.showsReason(for: makeUnverified()))
        #expect(UnverifiedRequestBadge.showsReason(for: makeUnverified(reason: .noShowLimit)))
        #expect(UnverifiedRequestBadge.showsReason(for: makeIncomingBooking(reason: nil)))
        #expect(UnverifiedRequestBadge.showsReason(for: makeIncomingBooking(reason: .newClient)))
    }

    @Test("The server fields decode from the booking document and are optional")
    func decoding() throws {
        let json = """
        {"id":"bk-9","status":"pendingApproval","serviceId":"svc","serviceName":"Glow","startsAt":0,"endsAt":3600,
         "client":{"name":"Ana","phone":"+5511981234410"},"verification":"whatsapp","reference":"K7M2P",
         "pendingExpiresAt":86400}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let booking = try decoder.decode(IncomingBooking.self, from: Data(json.utf8))
        #expect(booking.verification == "whatsapp")
        #expect(booking.reference == "K7M2P")
        #expect(booking.pendingExpiresAt == Date(timeIntervalSince1970: 86_400))

        let plain = try decoder.decode(IncomingBooking.self, from: Data("""
        {"id":"bk-9","status":"confirmed","serviceId":"svc","serviceName":"Glow","startsAt":0,"endsAt":3600,
         "client":{"name":"Ana","phone":"+5511981234410"}}
        """.utf8))
        #expect(plain.verification == nil && plain.reference == nil && plain.pendingExpiresAt == nil)
    }
}
