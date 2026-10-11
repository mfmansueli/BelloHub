//
//  QuickReplyUpgradeTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("QuickReplyUpgrade")
struct QuickReplyUpgradeTests {
    private func stored(_ builtIn: BuiltInQuickReply, text: String) -> QuickReply {
        QuickReply(
            id: builtIn.id, builtInKey: builtIn.rawValue, title: builtIn.title(in: .en), text: text,
            position: builtIn.position, updatedAt: TestClock.days(-30)
        )
    }

    @Test("A built-in still worded as the previous default gets the new one, in the business language")
    func upgradesUntouched() throws {
        let old = try #require(BuiltInQuickReply.confirm.previousText(in: .ptBR))
        let replies = [stored(.confirm, text: old)]
        let upgraded = QuickReplyUpgrade.upgraded(replies, localization: .ptBR, now: TestClock.now)
        #expect(upgraded.count == 1)
        #expect(upgraded.first?.text == BuiltInQuickReply.confirm.text(in: .ptBR))
        #expect(upgraded.first?.updatedAt == TestClock.now)
    }

    @Test("Her business language changed since: the old wording in any language is still recognized")
    func otherLanguage() throws {
        let old = try #require(BuiltInQuickReply.reschedule.previousText(in: .de))
        let replies = [stored(.reschedule, text: old)]
        let upgraded = QuickReplyUpgrade.upgraded(replies, localization: .en, now: TestClock.now)
        #expect(upgraded.first?.text == BuiltInQuickReply.reschedule.text(in: .en))
    }

    @Test("Anything she edited, a reply she wrote, and the unchanged built-ins stay as they are")
    func leavesHerWords() throws {
        let edited = stored(.confirm, text: "Hi {name}! See you {date}. {link}")
        let own = QuickReply(
            id: UUID(), builtInKey: nil, title: "Mine", text: "Hi {name}", position: 9, updatedAt: TestClock.now
        )
        let late = stored(.late, text: BuiltInQuickReply.late.text(in: .en))
        let current = stored(.confirm, text: BuiltInQuickReply.confirm.text(in: .en))
        #expect(QuickReplyUpgrade.upgraded([edited, own, late, current], localization: .en, now: TestClock.now).isEmpty)
    }
}
