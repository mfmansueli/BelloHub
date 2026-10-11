//
//  MessageLinksTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("MessageLinks")
struct MessageLinksTests {
    @Test("A WhatsApp link carries the digits of the number and the text, percent-encoded")
    func whatsApp() {
        let url = MessageLinks.whatsApp(phoneE164: "+5511981234410", text: "Hi Ana!")

        #expect(url?.absoluteString == "https://wa.me/5511981234410?text=Hi%20Ana%21")
    }

    @Test("Characters that could end the text early are encoded", arguments: ["&", "=", "+", "#", "?", "%", "/"])
    func reservedCharacters(character: String) throws {
        let url = try #require(MessageLinks.whatsApp(phoneE164: "+5511981234410", text: "a\(character)b"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.queryItems?.count == 1)
        #expect(components.queryItems?.first?.value == "a\(character)b")
        #expect(url.fragment == nil)
    }

    @Test("Right-to-left, accented and emoji text survives a round trip")
    func unicodeRoundTrip() throws {
        let text = "مرحبًا Ana, até já! 😊 — 15:00"
        let url = try #require(MessageLinks.whatsApp(phoneE164: "+966501234567", text: text))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.queryItems?.first?.value == text)
    }

    @Test("A number that is not in international form gives no link", arguments: [
        nil, "", "5511981234410", "+55", "abc", "+1234567890123456"
    ] as [String?])
    func invalidNumbers(phone: String?) {
        #expect(MessageLinks.whatsApp(phoneE164: phone, text: "x") == nil)
        #expect(MessageLinks.sms(phoneE164: phone, text: "x") == nil)
    }

    @Test("An empty text opens the chat without a text parameter")
    func emptyText() {
        #expect(MessageLinks.whatsApp(phoneE164: "+5511981234410", text: "")?.absoluteString
            == "https://wa.me/5511981234410")
    }

    @Test("An SMS link uses the form every iOS version understands")
    func sms() {
        #expect(MessageLinks.sms(phoneE164: "+5511981234410", text: "Hi Ana")?.absoluteString
            == "sms:+5511981234410&body=Hi%20Ana")
    }

    @Test("Arabic-Indic digits in a stored number are read as the digits they are")
    func arabicIndicDigits() {
        #expect(MessageLinks.digits(ofE164: "+٩٦٦٥٠١٢٣٤٥٦٧") == "966501234567")
    }
}
