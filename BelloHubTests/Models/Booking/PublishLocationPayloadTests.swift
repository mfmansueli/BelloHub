//
//  PublishLocationPayloadTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Where she works (`publishProfile.profile.location`, API.md 6.2): the lines and links the app formats, and who may
/// see them. Nothing goes out until she saves a complete address.
@Suite("PublishPayloads: the address")
struct PublishLocationPayloadTests {
    private let now = TestClock.now

    private func inputs(_ location: BusinessLocation?) -> PublishInputs {
        var inputs = makePublishInputs()
        inputs.setup.location = location
        return inputs
    }

    private let address = BusinessLocation(
        street: "Rua Augusta 1200", postalCode: "01304-001", city: "São Paulo", countryCode: "BR",
        directions: "2º andar"
    )

    @Test("No address saved: the page goes out without one")
    func none() {
        #expect(PublishPayloads.profile(inputs(nil), now: now).profile.location == nil)
    }

    @Test("A saved address goes out as its lines, the note, both map links and who may see it")
    func published() throws {
        let sent = try #require(PublishPayloads.profile(inputs(address), now: now).profile.location)
        #expect(sent.lines == ["Rua Augusta 1200", "São Paulo 01304-001"])
        #expect(sent.directions == "2º andar")
        #expect(sent.maps.apple.hasPrefix("https://maps.apple.com/?address="))
        #expect(sent.maps.google.hasPrefix("https://www.google.com/maps/search/?api=1&query="))
        #expect(sent.visibility == "confirmed", "the default keeps it to confirmed clients")
        var open = address
        open.visibility = .bookingPage
        #expect(PublishPayloads.profile(inputs(open), now: now).profile.location?.visibility == "public")
    }

    @Test("An incomplete or too long address publishes no address rather than a refused page")
    func refusedLocally() {
        var empty = address
        empty.city = " "
        #expect(PublishPayloads.profile(inputs(empty), now: now).profile.location == nil)
        var long = address
        long.street = String(repeating: "a", count: 121)
        #expect(PublishPayloads.profile(inputs(long), now: now).profile.location == nil)
    }

    @Test("The request matches the server's contract")
    func contract() throws {
        var open = address
        open.visibility = .bookingPage
        let body = try CallableJSON.encoder.encode(PublishPayloads.profile(inputs(open), now: now))
        for problem in try ServerContract.violations(of: body, for: "publishProfile") {
            Issue.record(Comment(rawValue: problem))
        }
        #expect(String(bytes: body, encoding: .utf8)?.contains("\"location\"") == true)
    }
}
