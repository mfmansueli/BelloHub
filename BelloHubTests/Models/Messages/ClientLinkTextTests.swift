//
//  ClientLinkTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientLinkText")
struct ClientLinkTextTests {
    private let link = "https://bellohub.app/m/AbCdEfGhIjKlMnOpQrStUv"

    @Test("A link in a message is the full address, never the short form people read")
    func fullAddress() throws {
        let url = try #require(URL(string: "https://bellohub.app/maria"))
        #expect(ClientLinkText.text(url) == "https://bellohub.app/maria")
        #expect(BookingLink(slug: "maria").messageText == "https://bellohub.app/maria")
        #expect(BookingLink(slug: "maria").display == "bellohub.app/maria")
    }

    @Test("A link glued inside a sentence moves to its own line, and the rest to the next")
    func midSentence() {
        let text = "Reply YES or use \(link) to change it."
        #expect(ClientLinkText.placeOnOwnLine(link, in: text) == "Reply YES or use\n\(link)\nto change it.")
    }

    @Test("Closing punctuation glued after the link is dropped, so it never becomes part of the link", arguments: [
        ".", "!", "?", ")", "…", "。", "؟", "،", " .", ".\u{2069}"
    ])
    func trailingPunctuation(tail: String) {
        #expect(ClientLinkText.placeOnOwnLine(link, in: "Book here: \(link)\(tail)") == "Book here:\n\(link)")
    }

    @Test("A link already on its own line is left alone")
    func alreadyAlone() {
        let text = "Your link:\n\(link)\n\nSee you soon."
        #expect(ClientLinkText.placeOnOwnLine(link, in: text) == text)
        #expect(ClientLinkText.placeOnOwnLine(link, in: link) == link)
    }

    @Test("Every occurrence is placed; a text without the link, or an empty link, comes back unchanged")
    func occurrences() {
        #expect(ClientLinkText.placeOnOwnLine(link, in: "\(link) and \(link)") == "\(link)\nand\n\(link)")
        #expect(ClientLinkText.placeOnOwnLine(link, in: "No link here.") == "No link here.")
        #expect(ClientLinkText.placeOnOwnLine("", in: "Text") == "Text")
    }

    @Test("Arabic text keeps the link alone on its line, with no isolate around it")
    func arabic() {
        let text = "يمكنك الحجز من هنا: \(link)"
        let placed = ClientLinkText.placeOnOwnLine(link, in: text)
        #expect(placed == "يمكنك الحجز من هنا:\n\(link)")
        #expect(!placed.contains("\u{2066}") && !placed.contains("\u{2069}"))
    }

    @Test("A block is appended on lines of its own; an empty block changes nothing")
    func append() {
        #expect(ClientLinkText.appendOnOwnLine(link, to: "Book here: ") == "Book here:\n\(link)")
        #expect(ClientLinkText.appendOnOwnLine(link, to: "Book here:\n") == "Book here:\n\(link)")
        #expect(ClientLinkText.appendOnOwnLine(link, to: "") == link)
        #expect(ClientLinkText.appendOnOwnLine("", to: "Hi") == "Hi")
    }
}
