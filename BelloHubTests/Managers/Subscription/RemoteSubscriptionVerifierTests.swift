//
//  RemoteSubscriptionVerifierTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The server as the source of truth for her plan (D33, D42): the purchase carries the account token `ensureAccount`
/// gave, `syncPlan` re-verifies the signed transaction and its answer is what the app believes; an explicit rejection
/// means no plan, and an unreachable or unconfigured server leaves the store's answer to the caller.
@Suite("RemoteSubscriptionVerifier")
struct RemoteSubscriptionVerifierTests {
    private static let token = "8d1b1f3e-1b8f-4a5e-9f5e-0a1b2c3d4e5f"
    private static let accountJSON = """
    {"uid":"u1","appAccountToken":"\(token)","dataRegion":"eu",\
    "registrations":{"count":10,"freeLimit":10},"plan":{"state":"none"}}
    """
    private static let jws = "eyJhbGciOiJFUzI1NiJ9.eyJwcm9kdWN0SWQiOiJjb20uYmVsbG9odWIucHJvLm1vbnRobHkifQ.c2ln"
    private static let storeActive = SubscriptionState.active(period: .yearly, expiresAt: nil, willRenew: false)

    private func make(
        profile: ProfessionalProfile? = makeProfessionalProfile()
    ) -> (RemoteSubscriptionVerifier, FakeCallableClient) {
        let client = FakeCallableClient()
        let verifier = RemoteSubscriptionVerifier(
            client: client, accounts: RemoteBookingRepository(client: client), profile: { profile }
        )
        return (verifier, client)
    }

    // MARK: - Account token

    @Test("The purchase token is the account's appAccountToken, asked with her region and language")
    func purchaseToken() async throws {
        let (verifier, client) = make()
        client.answer("ensureAccount", with: Self.accountJSON)

        let token = try await verifier.purchaseToken()

        #expect(token == UUID(uuidString: Self.token))
        let call = try #require(client.calls.first)
        #expect(call.function == "ensureAccount")
        #expect(call.object["countryCode"] as? String == "BR")
        #expect(call.object["locale"] as? String == "pt-BR")
    }

    @Test("No token, no purchase: offline, no profile or a malformed token all throw accountUnavailable")
    func purchaseTokenFailures() async {
        let (offline, offlineClient) = make()
        offlineClient.fail("ensureAccount", with: .network)
        await #expect(throws: SubscriptionError.accountUnavailable) { try await offline.purchaseToken() }

        let (noProfile, noProfileClient) = make(profile: nil)
        await #expect(throws: SubscriptionError.accountUnavailable) { try await noProfile.purchaseToken() }
        #expect(noProfileClient.calls.isEmpty, "nothing is asked of the server without a profile")

        let (malformed, malformedClient) = make()
        malformedClient.answer("ensureAccount", with: Self.accountJSON.replacingOccurrences(of: Self.token, with: "x"))
        await #expect(throws: SubscriptionError.accountUnavailable) { try await malformed.purchaseToken() }
    }

    // MARK: - Verification

    @Test("syncPlan receives the signed transaction, valid against the server contract")
    func syncPlanRequest() async throws {
        let (verifier, client) = make()
        client.answer("syncPlan", with: #"{"plan":{"state":"active","expiresAt":"2026-11-01T12:00:00.000Z"}}"#)

        _ = try await verifier.verify(Self.storeActive, signedTransaction: Self.jws)

        let call = try #require(client.calls.first)
        #expect(call.function == "syncPlan")
        #expect(call.object["signedTransaction"] as? String == Self.jws)
        #expect(try ServerContract.violations(of: call.body, for: "syncPlan").isEmpty)
    }

    @Test("The server's plan wins: its dates, the store's period and renewal flag")
    func serverActive() async throws {
        let (verifier, client) = make()
        client.answer("syncPlan", with: #"{"plan":{"state":"active","expiresAt":"2026-11-01T12:00:00.000Z"}}"#)

        let state = try await verifier.verify(Self.storeActive, signedTransaction: Self.jws)

        let expires = try #require(CallableJSON.parse("2026-11-01T12:00:00.000Z"))
        #expect(state == .active(period: .yearly, expiresAt: expires, willRenew: false))
    }

    @Test("Grace on the server is grace in the app")
    func serverGrace() async throws {
        let (verifier, client) = make()
        client.answer("syncPlan", with: #"{"plan":{"state":"grace","expiresAt":"2026-10-05T12:00:00.000Z"}}"#)

        let state = try await verifier.verify(Self.storeActive, signedTransaction: Self.jws)

        #expect(state == .inGracePeriod(period: .yearly, expiresAt: CallableJSON.parse("2026-10-05T12:00:00.000Z")))
    }

    @Test("Expired, revoked (a refund) or none on the server: no plan, whatever the store says", arguments: [
        "expired", "revoked", "none"
    ])
    func serverNoPlan(serverState: String) async throws {
        let (verifier, client) = make()
        client.answer("syncPlan", with: #"{"plan":{"state":"\#(serverState)"}}"#)

        let state = try await verifier.verify(Self.storeActive, signedTransaction: Self.jws)

        #expect(state == .none)
        #expect(!state.hasActivePlan)
    }

    @Test("A transaction the server says is not hers unlocks nothing")
    func verificationFailed() async throws {
        let (verifier, client) = make()
        client.fail("syncPlan", with: .unexpected(code: "VERIFICATION_FAILED"))

        #expect(try await verifier.verify(Self.storeActive, signedTransaction: Self.jws) == .none)
    }

    @Test("Offline, busy or not configured (H14) is thrown, so the caller keeps the store's answer", arguments: [
        ServerError.network, .unavailable, .notConfigured, .rateLimited(retryAfterSeconds: 30)
    ])
    func transientFailuresThrow(error: ServerError) async {
        let (verifier, client) = make()
        client.fail("syncPlan", with: error)

        await #expect(throws: ServerError.self) {
            try await verifier.verify(Self.storeActive, signedTransaction: Self.jws)
        }
    }

    @Test("No signed transaction: nothing to prove, the server is not asked")
    func noTransaction() async throws {
        let (verifier, client) = make()

        #expect(try await verifier.verify(.none, signedTransaction: nil) == .none)
        #expect(try await verifier.verify(.unknown, signedTransaction: "") == .unknown)
        #expect(client.calls.isEmpty)
    }

    @Test("Through SubscriptionService: a NOT_CONFIGURED server keeps the store's signed answer")
    @MainActor
    func serviceKeepsStoreWhenNotConfigured() async {
        let (verifier, client) = make()
        client.fail("syncPlan", with: .notConfigured)
        let provider = FakeSubscriptionProvider(state: Self.storeActive)
        provider.signedTransaction = Self.jws
        let service = SubscriptionService(provider: provider, verifier: verifier)

        await service.refreshState()

        #expect(service.state == Self.storeActive)
        #expect(client.calls.map(\.function) == ["syncPlan"])
    }
}
