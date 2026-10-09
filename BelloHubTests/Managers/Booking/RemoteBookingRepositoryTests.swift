//
//  RemoteBookingRepositoryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RemoteBookingRepository")
struct RemoteBookingRepositoryTests {
    private func make() -> (RemoteBookingRepository, FakeCallableClient) {
        let client = FakeCallableClient()
        return (RemoteBookingRepository(client: client), client)
    }

    private let accountJSON = """
    {"uid":"u1","appAccountToken":"8d1b1f3e-1b8f-4a5e-9f5e-0a1b2c3d4e5f","dataRegion":"eu",\
    "registrations":{"count":2,"freeLimit":10},"plan":{"state":"none"},"slug":"maria"}
    """

    // MARK: - Address

    @Test("The address check asks isSlugAvailable and maps the answer", arguments: [
        (#"{"available":true}"#, SlugAvailability.available),
        (#"{"available":false,"reason":"taken"}"#, .taken),
        (#"{"available":false,"reason":"reserved"}"#, .reserved),
        (#"{"available":false,"reason":"invalid"}"#, .invalid),
        (#"{"available":false}"#, .invalid)
    ])
    func slugCheck(answer: String, expected: SlugAvailability) async throws {
        let (repository, client) = make()
        client.answer("isSlugAvailable", with: answer)
        #expect(try await repository.isSlugAvailable("maria") == expected)
        #expect(client.calls.map(\.function) == ["isSlugAvailable"])
        #expect(client.calls.first?.object as? [String: String] == ["slug": "maria"])
    }

    @Test("Claiming an address: the server's refusals become friendly errors")
    func claim() async throws {
        let (repository, client) = make()
        client.answer("claimSlug", with: #"{"slug":"maria"}"#)
        try await repository.claimSlug("maria")
        #expect(client.calls.first?.object as? [String: String] == ["slug": "maria"])

        client.fail("claimSlug", with: .slugTaken)
        await #expect(throws: BookingRepositoryError.slugTaken) { try await repository.claimSlug("maria") }
        client.fail("claimSlug", with: .invalidArgument(fields: ["slug"]))
        await #expect(throws: BookingRepositoryError.slugInvalid) { try await repository.claimSlug("maria") }
    }

    // MARK: - Account

    @Test("ensureAccount sends the country and the language and reads the account")
    func ensureAccount() async throws {
        let (repository, client) = make()
        client.answer("ensureAccount", with: accountJSON)
        let account = try await repository.ensureAccount(countryCode: "BR", locale: "pt-BR")
        #expect(account.uid == "u1" && account.slug == "maria" && account.registrations.freeLimit == 10)
        #expect(account.appAccountToken == "8d1b1f3e-1b8f-4a5e-9f5e-0a1b2c3d4e5f")
        #expect(client.calls.first?.object as? [String: String] == ["countryCode": "BR", "locale": "pt-BR"])
    }

    @Test("An account with no address yet has a nil slug")
    func accountWithoutSlug() async throws {
        let (repository, client) = make()
        client.answer("ensureAccount", with: """
        {"uid":"u1","appAccountToken":"t","dataRegion":"eu","registrations":{"count":0,"freeLimit":10},\
        "plan":{"state":"none"}}
        """)
        #expect(try await repository.ensureAccount(countryCode: "PT", locale: "pt-PT").slug == nil)
    }

    // MARK: - Publishing

    @Test("Publishing the page and the availability call their functions with what the builders made")
    func publish() async throws {
        let (repository, client) = make()
        client.answer("publishProfile", with: #"{"slug":"maria","updatedAt":"2026-10-01T15:00:00.000Z"}"#)
        client.answer("publishAvailability", with: #"{"updatedAt":"2026-10-01T15:00:00.000Z"}"#)
        let inputs = makePublishInputs()
        try await repository.publishProfile(PublishPayloads.profile(inputs, now: TestClock.now))
        try await repository.publishAvailability(PublishPayloads.availability(inputs, now: TestClock.now))
        #expect(client.calls.map(\.function) == ["publishProfile", "publishAvailability"])
        #expect(Set(client.calls[0].object.keys) == ["profile"])
        #expect(client.calls[1].object["timeZoneID"] as? String == "America/Sao_Paulo")
    }

    @Test("Stopping online booking for a client and rotating the inbox key")
    func smallCalls() async throws {
        let (repository, client) = make()
        client.answer("setOnlineBookingStopped", with: #"{"ok":true}"#)
        client.answer(
            "updateInboxKey", with: #"{"keyring":[{"keyId":"AAAAAAAAAAA","createdAt":"2026-10-01T15:00:00.000Z"}]}"#
        )
        try await repository.setOnlineBookingStopped(phone: "+5511987654321", stopped: true)
        try await repository.updateInboxKey(makeInboxKey(), compromised: false)
        try await repository.updateInboxKey(makeInboxKey(), compromised: true)
        #expect(client.calls[0].object["phone"] as? String == "+5511987654321")
        #expect(client.calls[0].object["stopped"] as? Bool == true)
        #expect(client.calls[1].object["compromised"] == nil)
        #expect(client.calls[2].object["compromised"] as? Bool == true)
        let key = client.calls[1].object["inboxKey"] as? [String: String]
        #expect(key == ["keyId": "AAAAAAAAAAA", "alg": "hpke-v1", "pub": makeInboxKey().pub])
    }

    // MARK: - Mapping

    @Test("Every server error becomes one repository error", arguments: [
        (ServerError.network, BookingRepositoryError.unreachable),
        (.unavailable, .busy),
        (.rateLimited(retryAfterSeconds: 5), .busy),
        (.unauthenticated, .unauthenticated),
        (.forbidden, .unauthenticated),
        (.slugTaken, .slugTaken),
        (.invalidArgument(fields: ["x"]), .rejected),
        (.notFound, .rejected),
        (.notConfigured, .rejected),
        (.conflict, .rejected),
        (.payloadTooLarge, .rejected),
        (.unexpected(code: "DECODE"), .rejected)
    ])
    func mapping(server: ServerError, expected: BookingRepositoryError) async {
        #expect(RemoteBookingRepository.map(server) == expected)
        let (repository, client) = make()
        client.fail("ensureAccount", with: server)
        await #expect(throws: expected) { try await repository.ensureAccount(countryCode: "BR", locale: "pt-BR") }
    }
}
