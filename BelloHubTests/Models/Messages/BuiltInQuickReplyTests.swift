//
//  BuiltInQuickReplyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BuiltInQuickReply")
struct BuiltInQuickReplyTests {
    private let now = TestClock.now
    private static let words = QuickReplyVariable.allCases.map(\.token)

    @Test("There are six, with fixed ids and positions")
    func six() {
        #expect(BuiltInQuickReply.allCases.count == 6)
        #expect(Set(BuiltInQuickReply.allCases.map(\.id)).count == 6)
        #expect(BuiltInQuickReply.allCases.map(\.position) == [0, 1, 2, 3, 4, 5])
        #expect(BuiltInQuickReply.allCases.map(\.rawValue) == ["confirm", "late", "reschedule", "aftercare",
            "checkIn", "comeBack"])
    }

    @Test("The English defaults are the prototype's")
    func english() {
        #expect(BuiltInQuickReply.confirm.title(in: .en) == "Confirm appointment")
        #expect(BuiltInQuickReply.confirm.text(in: .en)
            == """
            Hi {name}! Your {service} is booked for {date} at {time}.

            {address}

            If you need to make any changes, cancel (according to our policy), or get directions on \
            Google Maps or Apple Maps, please use your exclusive link:
            {link}

            We look forward to seeing you!
            {business}
            """)
        #expect(BuiltInQuickReply.late.text(in: .en)
            == "Hi {name}, I am running about 10 minutes behind. Thank you for your patience!")
        #expect(BuiltInQuickReply.reschedule.text(in: .en)
            == "Hi {name}, I need to move your {service}.\n{address}\nPlease choose a new time here:\n{link}")
    }

    @Test("Confirm and Reschedule carry the address and the link on its own line, in every localization",
          arguments: AppLocalization.allCases)
    func linkLastAndAddress(localization: AppLocalization) {
        let confirmText = BuiltInQuickReply.confirm.text(in: localization)
        #expect(confirmText.contains("\n{address}\n"), "\(localization.rawValue) confirm")
        #expect(confirmText.contains("\n{link}\n"), "\(localization.rawValue) confirm")
        #expect(confirmText.hasSuffix("\n{business}"), "\(localization.rawValue) confirm")

        let rescheduleText = BuiltInQuickReply.reschedule.text(in: localization)
        #expect(rescheduleText.contains("\n{address}\n"), "\(localization.rawValue) reschedule")
        #expect(rescheduleText.hasSuffix("\n{link}"), "\(localization.rawValue) reschedule")

        for builtIn in [BuiltInQuickReply.confirm, .reschedule] {
            let previous = builtIn.previousText(in: localization)
            #expect(previous?.isEmpty == false && previous != builtIn.text(in: localization))
        }
        #expect(BuiltInQuickReply.late.previousText(in: localization) == nil)
    }

    @Test("Every default exists in every localization with the same words in braces as English",
          arguments: AppLocalization.allCases)
    func everyLocalization(localization: AppLocalization) {
        for builtIn in BuiltInQuickReply.allCases {
            let title = builtIn.title(in: localization)
            let text = builtIn.text(in: localization)
            #expect(!title.isEmpty && !title.contains("quickReplies.default"), "\(localization.rawValue) \(builtIn)")
            #expect(!text.isEmpty && !text.contains("quickReplies.default"), "\(localization.rawValue) \(builtIn)")
            #expect(
                QuickReplyRenderer.words(in: text) == QuickReplyRenderer.words(in: builtIn.text(in: .en)),
                "\(localization.rawValue) \(builtIn) changed the words in braces: \(text)"
            )
            #expect(QuickReplyRenderer.unknownWords(in: text).isEmpty)
            #expect(text.count <= QuickReply.maxTextLength)
        }
    }

    @Test("No default speaks of skin or any clinical detail: they are general across professions",
          arguments: AppLocalization.allCases)
    func noClinicalContent(localization: AppLocalization) {
        let forbidden = ["skin", "pele", "piel", "peau", "haut", "pelle", "cilt", "kulit"]
        for builtIn in BuiltInQuickReply.allCases {
            let text = builtIn.text(in: localization).lowercased()
            for word in forbidden {
                #expect(!text.contains(word), "\(localization.rawValue) \(builtIn) mentions \(word)")
            }
        }
    }

    @Test("Default titles are short enough for a row")
    func titles() {
        for localization in AppLocalization.allCases {
            for builtIn in BuiltInQuickReply.allCases {
                #expect(builtIn.title(in: localization).count <= QuickReply.maxTitleLength)
            }
        }
    }

    @Test("A built-in message becomes a stored reply that remembers where it came from")
    func asReply() {
        let reply = BuiltInQuickReply.aftercare.reply(in: .ptBR, now: now)
        #expect(reply.id == BuiltInQuickReply.aftercare.id)
        #expect(reply.builtIn == .aftercare && reply.builtInKey == "aftercare")
        #expect(reply.position == 3 && reply.updatedAt == now)
        #expect(reply.title == BuiltInQuickReply.aftercare.title(in: .ptBR))
        #expect(reply.text == BuiltInQuickReply.aftercare.text(in: .ptBR))
    }

    @Test("A reply written by her, or from a key this version does not know, has no built-in")
    func noBuiltIn() {
        let own = QuickReply(id: UUID(), builtInKey: nil, title: "Mine", text: "Hi", position: 0, updatedAt: now)
        #expect(own.builtIn == nil)
        let future = QuickReply(id: UUID(), builtInKey: "newKind", title: "Mine", text: "Hi", position: 0,
            updatedAt: now)
        #expect(future.builtIn == nil)
    }

    @Test("A stored reply survives encoding")
    func coding() throws {
        let reply = BuiltInQuickReply.comeBack.reply(in: .de, now: now)
        let decoded = try JSONDecoder().decode(QuickReply.self, from: JSONEncoder().encode(reply))
        #expect(decoded == reply)
    }
}
