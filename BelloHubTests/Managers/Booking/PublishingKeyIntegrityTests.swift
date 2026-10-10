//
//  PublishingKeyIntegrityTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// Public-key integrity (docs/06 section 3.2): after a publish the page must serve the key this iPhone derived. An
/// honest server passes, a swapped key is published over once, and a key that stays wrong stops publishing.
@Suite("PublishingService: inbox key integrity")
@MainActor
struct PublishingKeyIntegrityTests {
    private let userID = PublishingRig.userID

    private static func strangerKey() -> InboxPublicKey {
        InboxPublicKey(publicKey: Curve25519.KeyAgreement.PrivateKey().publicKey)
    }

    @Test("An honest server: the served key is read once and the page is online")
    func honestServer() async {
        let rig = PublishingRig()
        defer { rig.cleanUp() }
        rig.service.start(userID: userID)

        await rig.service.goOnlineAsync()

        #expect(rig.service.state == .online)
        #expect(await rig.repository.servedKeyReads == 1)
        #expect(await rig.repository.profiles.count == 1)
    }

    @Test("A page that keeps serving another key: published over once, then publishing stops with keyMismatch")
    func swappedKeyStops() async {
        let rig = PublishingRig()
        defer { rig.cleanUp() }
        await rig.repository.setServedKeyOverride(Self.strangerKey())
        rig.service.start(userID: userID)

        await rig.service.goOnlineAsync()

        #expect(rig.service.state == .error(.keyMismatch, wasOnline: false))
        #expect(await rig.repository.profiles.count == 2, "the first publish and one republish")
        #expect(await rig.repository.servedKeyReads == 2)

        // Another change does not publish while the key is wrong.
        rig.source.update { $0.setup.slug = "maria-silva" }
        await rig.service.syncNow()
        #expect(await rig.repository.profiles.count == 2)
        #expect(rig.service.state == .error(.keyMismatch, wasOnline: false))
    }

    @Test("A swap the republish fixes is not an error")
    func republishFixes() async throws {
        let repository = FakeBookingRepository()
        await repository.setServedKeyOverride(Self.strangerKey())
        var republished = 0

        try await InboxKeyVerifier(repository: repository).verify(expected: Self.strangerKey(), slug: "maria") {
            republished += 1
            await repository.setServedKeyOverride(nil)
        }

        #expect(republished == 1)
        #expect(await repository.servedKeyReads == 2)
    }

    @Test("Retry after the server is fixed publishes again")
    func retryAfterFix() async {
        let rig = PublishingRig()
        defer { rig.cleanUp() }
        await rig.repository.setServedKeyOverride(Self.strangerKey())
        rig.service.start(userID: userID)
        await rig.service.goOnlineAsync()
        #expect(rig.service.state == .error(.keyMismatch, wasOnline: false))

        await rig.repository.setServedKeyOverride(nil)
        await rig.service.retryAsync()

        #expect(rig.service.state == .online)
    }

    @Test("The verifier compares the public key and its id")
    func matching() {
        let mine = Self.strangerKey()
        #expect(InboxKeyVerifier.matches(mine, mine))
        #expect(!InboxKeyVerifier.matches(Self.strangerKey(), mine))
    }

    @Test("A key mismatch reads as its own failure, offers retry and is not retried by itself")
    func failureMapping() {
        #expect(PublishingService.failure(for: InboxKeyMismatchError()) == .keyMismatch)
        #expect(!PublishFailure.keyMismatch.isRetryable)
        #expect(PublishStatusText.offersRetry(.keyMismatch))
    }
}
