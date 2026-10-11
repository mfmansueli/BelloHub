//
//  QuickReplyRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("QuickReplyRules")
struct QuickReplyRulesTests {
    private let now = TestClock.now

    private func reply(_ title: String = "Late", position: Int = 0, builtIn: String? = nil, text: String = "Hi {name}")
        -> QuickReply {
        QuickReply(id: UUID(), builtInKey: builtIn, title: title, text: text, position: position, updatedAt: now)
    }

    @Test("A reply needs a name and a message, and the message has a limit")
    func issues() {
        #expect(QuickReplyRules.issue(title: "", text: "Hi") == .nameEmpty)
        #expect(QuickReplyRules.issue(title: "  \n", text: "Hi") == .nameEmpty)
        #expect(QuickReplyRules.issue(title: "Late", text: "") == .textEmpty)
        #expect(QuickReplyRules.issue(title: "Late", text: " \n ") == .textEmpty)
        #expect(QuickReplyRules.issue(title: "Late", text: String(repeating: "a", count: 1000)) == nil)
        #expect(QuickReplyRules.issue(title: "Late", text: String(repeating: "a", count: 1001)) == .textTooLong)
        #expect(QuickReplyRules.issue(title: "Late", text: "Hi {name}") == nil)
    }

    @Test("The limit counts the message without the blank space around it")
    func limitIgnoresPadding() {
        let padded = "  " + String(repeating: "a", count: 1000) + "  "
        #expect(QuickReplyRules.issue(title: "Late", text: padded) == nil)
    }

    @Test("A new reply goes to the end, trimmed")
    func making() throws {
        let existing = [reply("A", position: 0), reply("B", position: 4)]
        let new = try #require(QuickReplyRules.making(title: "  Thanks  ", text: "\nThank you {name}!\n",
            among: existing, now: now))
        #expect(new.title == "Thanks" && new.text == "Thank you {name}!" && new.position == 5)
        #expect(new.builtInKey == nil && new.updatedAt == now)
    }

    @Test("The first reply of an empty list is at position 0")
    func firstPosition() throws {
        let first = try #require(QuickReplyRules.making(title: "A", text: "B", among: [], now: now))
        #expect(first.position == 0)
    }

    @Test("A reply that is not valid is not made")
    func notMade() {
        #expect(QuickReplyRules.making(title: "", text: "Hi", among: [], now: now) == nil)
        #expect(QuickReplyRules.making(title: "A", text: "", among: [], now: now) == nil)
    }

    @Test("A long name is cut to the limit")
    func longName() throws {
        let new = try #require(QuickReplyRules.making(title: String(repeating: "x", count: 90), text: "Hi",
            among: [], now: now))
        #expect(new.title.count == QuickReply.maxTitleLength)
    }

    @Test("Updating keeps the identity, the origin and the place")
    func updating() throws {
        let original = reply("Late", position: 3, builtIn: "late")
        let later = now.addingTimeInterval(60)
        let updated = try #require(QuickReplyRules.updating(original, title: "Running late", text: "Hi {name}!",
            now: later))
        #expect(updated.id == original.id && updated.builtInKey == "late" && updated.position == 3)
        #expect(updated.title == "Running late" && updated.text == "Hi {name}!" && updated.updatedAt == later)
        #expect(QuickReplyRules.updating(original, title: "", text: "x", now: later) == nil)
    }

    @Test("A built-in reply can be put back as the catalog has it, in the place it is")
    func original() throws {
        var edited = BuiltInQuickReply.late.reply(in: .en, now: now)
        edited.text = "Changed"
        edited.position = 4
        #expect(QuickReplyRules.isEdited(edited, in: .en))
        let original = try #require(QuickReplyRules.original(of: edited, in: .en, now: now))
        #expect(original.text == BuiltInQuickReply.late.text(in: .en) && original.position == 4 && original.id
            == edited.id)
        #expect(!QuickReplyRules.isEdited(original, in: .en))
    }

    @Test("A reply in another language than the catalog's counts as edited; one she wrote never does")
    func edited() {
        let portuguese = BuiltInQuickReply.late.reply(in: .ptBR, now: now)
        #expect(QuickReplyRules.isEdited(portuguese, in: .en))
        #expect(!QuickReplyRules.isEdited(portuguese, in: .ptBR))
        let own = reply()
        #expect(!QuickReplyRules.isEdited(own, in: .en) && QuickReplyRules.original(of: own, in: .en, now: now) == nil)
    }

    @Test("Adding a word puts one space before it, unless the text already ends in space")
    func appending() {
        #expect(QuickReplyRules.appending(.name, to: "") == "{name}")
        #expect(QuickReplyRules.appending(.service, to: "Hi") == "Hi {service}")
        #expect(QuickReplyRules.appending(.link, to: "Hi ") == "Hi {link}")
        #expect(QuickReplyRules.appending(.time, to: "Hi\n") == "Hi\n{time}")
        #expect(QuickReplyRules.appending(.date, to: "Hi {name}") == "Hi {name} {date}")
    }
}
