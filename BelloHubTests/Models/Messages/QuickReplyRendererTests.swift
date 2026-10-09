//
//  QuickReplyRendererTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("QuickReplyRenderer")
struct QuickReplyRendererTests {
    /// Thursday 2026-10-01 at 15:00 in São Paulo.
    private let visit = TestClock.date("2026-10-01 15:00")

    private func formatters(_ localeID: String = "en_US") -> Formatters {
        Formatters(locale: Locale(identifier: localeID), timeZone: TestClock.saoPaulo, currencyCode: "BRL")
    }

    private var values: QuickReplyValues {
        QuickReplyValues(name: "Ana", service: "Glow Facial", startsAt: visit, link: "bellohub.app/maria")
    }

    @Test("Every word is filled in, with the locale's date and time")
    func fillsEveryWord() {
        let text = "Hi {name}! Your {service} is on {date} at {time}. Change it: {link}"
        let result = QuickReplyRenderer.render(text, values: values, formatters: formatters())
        // The 12-hour clock puts a narrow no-break space before PM; compare with a plain one.
        #expect(result.replacingOccurrences(of: "\u{202F}", with: " ")
            == "Hi Ana! Your Glow Facial is on Thursday, October 1 at 3:00 PM. Change it: bellohub.app/maria")
    }

    @Test("Dates and times follow the business locale", arguments: [
        ("pt_BR", "quinta-feira, 1 de outubro", "15:00"),
        ("de_DE", "Donnerstag, 1. Oktober", "15:00"),
        ("es_ES", "jueves, 1 de octubre", "15:00"),
        ("en_GB", "Thursday 1 October", "15:00")
    ])
    func localeDatesAndTimes(localeID: String, date: String, time: String) {
        let result = QuickReplyRenderer.render("{date}|{time}", values: values, formatters: formatters(localeID))
        #expect(result == "\(date)|\(time)")
    }

    @Test("The same word can appear twice")
    func repeats() {
        #expect(QuickReplyRenderer.render("{name} and {name}", values: values, formatters: formatters())
            == "Ana and Ana")
    }

    @Test("A word with no value is left as written, so she sees the gap")
    func missingValues() {
        let partial = QuickReplyValues(name: "Ana")
        let result = QuickReplyRenderer.render("Hi {name}, {service} at {time}: {link}", values: partial,
            formatters: formatters())
        #expect(result == "Hi Ana, {service} at {time}: {link}")
    }

    @Test("Unknown words and stray braces are sent as written")
    func unknownWords() {
        let text = "Hi {name}! {unknown} { name } {1} {}"
        #expect(QuickReplyRenderer.render(text, values: values, formatters: formatters())
            == "Hi Ana! {unknown} { name } {1} {}")
    }

    @Test("A value that contains a word in braces is not filled in again")
    func noRecursion() {
        let tricky = QuickReplyValues(name: "{service}", service: "Glow Facial")
        #expect(QuickReplyRenderer.render("Hi {name}", values: tricky, formatters: formatters()) == "Hi {service}")
    }

    @Test("Text without words comes back unchanged, including line breaks and emoji")
    func plainText() {
        let text = "Hello 🌸\nSee you soon."
        #expect(QuickReplyRenderer.render(text, values: values, formatters: formatters()) == text)
        #expect(QuickReplyRenderer.render("", values: values, formatters: formatters()).isEmpty)
    }

    @Test("In a right-to-left language every filled value is isolated")
    func bidi() {
        let result = QuickReplyRenderer.render(
            "{name} {service} {date} {time} {link}", values: values, formatters: formatters("ar_SA"), isolates: true
        )
        #expect(result.contains("\u{2068}Ana\u{2069}"))
        #expect(result.contains("\u{2068}Glow Facial\u{2069}"))
        #expect(result.contains("\u{2066}bellohub.app/maria\u{2069}"))
        #expect(result.contains("\u{2066}"))
        let plain = QuickReplyRenderer.render("{name}", values: values, formatters: formatters("ar_SA"))
        #expect(plain == "Ana")
    }

    @Test("The words in a message are listed once each, known or not")
    func wordsInText() {
        let text = "{name} {foo} {name} {link} {bar}"
        #expect(QuickReplyRenderer.words(in: text) == ["name", "foo", "link", "bar"])
        #expect(QuickReplyRenderer.unknownWords(in: text) == ["foo", "bar"])
        #expect(QuickReplyRenderer.unknownWords(in: "Hi {name} {service} {date} {time} {link}").isEmpty)
    }

    @Test("The five variables are the ones the prototype lists, written in braces")
    func variables() {
        #expect(QuickReplyVariable.allCases.map(\.token) == ["{name}", "{service}", "{date}", "{time}", "{link}"])
    }
}
