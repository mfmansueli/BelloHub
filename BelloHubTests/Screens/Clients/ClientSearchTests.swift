//
//  ClientSearchTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientSearch")
struct ClientSearchTests {
    private let vip = Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0)
    private let sensitive = Tag(id: UUID(), name: "Pele Sensível", colorToken: "sage", position: 1)

    private var clients: [Client] {
        [
            makeListedClient(name: "María José Costa", phone: "+5511981234410", tagIDs: [vip.id]),
            makeListedClient(name: "Beatriz Lima", phone: "+5511970001111", tagIDs: [sensitive.id]),
            makeListedClient(name: "Zoë Nguyen", phone: "+14155552671"),
            makeListedClient(name: "Gisele Matos")
        ]
    }

    private func found(_ query: String) -> [String] {
        let entries = ClientListBuilder.build(
            clients: clients, appointments: [], services: [], now: TestClock.now, calendar: TestClock.calendar()
        ).entries
        return ClientSearch.filter(entries, query: query, tags: [vip, sensitive]).map(\.client.name)
    }

    @Test("An empty or blank query keeps everyone")
    func emptyQuery() {
        #expect(found("").count == 4)
        #expect(found("   ").count == 4)
    }

    @Test("A name matches without regard to case or accents, anywhere in the name")
    func nameIsCaseAndAccentInsensitive() {
        #expect(found("maria") == ["María José Costa"])
        #expect(found("MARÍA") == ["María José Costa"])
        #expect(found("zoe") == ["Zoë Nguyen"])
        #expect(found("cost") == ["María José Costa"])
    }

    @Test("A phone number matches by its digits, however she types it")
    func phoneByDigits() {
        #expect(found("98123-4410") == ["María José Costa"])
        #expect(found("(11) 98123") == ["María José Costa"])
        #expect(found("+55 11 9700") == ["Beatriz Lima"])
        #expect(found("4155552671") == ["Zoë Nguyen"])
    }

    @Test("Digits typed in Arabic-Indic numerals find the same number")
    func arabicIndicDigits() {
        #expect(found("٩٨١٢٣") == ["María José Costa"])
    }

    @Test("A tag name matches too, ignoring accents and case")
    func tagNames() {
        #expect(found("vip") == ["María José Costa"])
        #expect(found("sensivel") == ["Beatriz Lima"])
    }

    @Test("Every word has to match something: a name and a number together narrow to one client")
    func allWordsMustMatch() {
        #expect(found("maria 98123") == ["María José Costa"])
        #expect(found("maria 9700").isEmpty)
        #expect(found("beatriz vip").isEmpty)
    }

    @Test("Nothing matches a word that is nowhere in the client")
    func noMatch() {
        #expect(found("xyz").isEmpty)
    }

    @Test("A digits-only word is not looked for in the notes or the email: only name, phone and tags are searched")
    func onlyNamePhoneAndTags() {
        var client = makeListedClient(name: "Ana", email: "ana@example.com", importantNote: "allergic to latex")
        client.allergies = ["fragrance"]

        #expect(!ClientSearch.matches(client, query: "latex", tags: []))
        #expect(!ClientSearch.matches(client, query: "example", tags: []))
        #expect(!ClientSearch.matches(client, query: "fragrance", tags: []))
        #expect(ClientSearch.matches(client, query: "ana", tags: []))
    }
}
