//
//  BookingLinkTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingLink")
struct BookingLinkTests {
    @Test("The link is the base address and the slug")
    func link() {
        let link = BookingLink(slug: "maria")
        #expect(link.url.absoluteString == "https://bellohub.app/maria")
        #expect(link.display == "bellohub.app/maria")
        #expect(link.host == "bellohub.app")
    }

    @Test("A staging base address is respected")
    func staging() throws {
        let base = try #require(URL(string: "https://staging.bellohub.app"))
        let link = BookingLink(slug: "maria-silva", baseURL: base)
        #expect(link.url.absoluteString == "https://staging.bellohub.app/maria-silva")
        #expect(link.display == "staging.bellohub.app/maria-silva")
    }
}
