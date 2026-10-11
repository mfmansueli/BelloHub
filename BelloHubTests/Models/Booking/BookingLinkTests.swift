//
//  BookingLinkTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingLink")
struct BookingLinkTests {
    @Test("The link is the configured web address and the slug (D54: Firebase Hosting until a domain exists)")
    func link() {
        let link = BookingLink(slug: "maria")
        #expect(link.url.absoluteString == "https://bellohub.app/maria")
        #expect(link.display == "bellohub.app/maria")
        // A message carries the full address, never the short form people read (ClientLinkText).
        #expect(link.messageText == "https://bellohub.app/maria")
        #expect(link.host == "bellohub.app")
    }

    @Test("The default base address is the one ServerConfig read from the build settings")
    func defaultBaseComesFromConfiguration() {
        #expect(BookingLink.defaultBaseURL == ServerConfig.current.webBaseURL)
    }

    @Test("A staging base address is respected")
    func staging() throws {
        let base = try #require(URL(string: "https://staging.bellohub.app"))
        let link = BookingLink(slug: "maria-silva", baseURL: base)
        #expect(link.url.absoluteString == "https://staging.bellohub.app/maria-silva")
        #expect(link.display == "staging.bellohub.app/maria-silva")
    }
}
