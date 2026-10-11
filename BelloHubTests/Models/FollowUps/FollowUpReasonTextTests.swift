//
//  FollowUpReasonTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The sentences of the queue (routine-a items 6 and 12): plain facts, no clinical wording, no promise, and an opened
/// chat never called "sent".
@Suite("FollowUpReasonText")
struct FollowUpReasonTextTests {
    private func text(_ id: String = "en_US") -> FollowUpReasonText {
        FollowUpReasonText(formatters: Formatters(
            locale: Locale(identifier: id), timeZone: TestClock.saoPaulo, currencyCode: "BRL"
        ))
    }

    @Test("A return says the service, its usual interval and that nothing is booked")
    func returnDue() {
        let sentence = text().why(.returnDue(serviceName: "Glow Facial", intervalWeeks: 6, lastVisit: TestClock.now))
        #expect(sentence.contains("Glow Facial") && sentence.contains("6 weeks"))
        #expect(sentence.contains("no return is booked"))
    }

    @Test("Opened is never sent: the line says WhatsApp does not confirm it; her mark is called hers")
    func delivery() {
        let opened = text().delivery(.conversationOpened(at: TestClock.now))
        #expect(opened.contains("does not confirm"))
        #expect(text().delivery(.markedSentByHer(at: TestClock.now)).hasPrefix("Marked as sent by you"))
        #expect(text().delivery(.readyToSend) == "Ready to send")
    }

    @Test("The reasons come in the reader's language", arguments: ["pt_BR", "pt_PT", "de_DE"])
    func localized(id: String) {
        let sentence = text(id).why(.notBack(daysSinceLastVisit: 74))
        #expect(!sentence.contains("Last visit"))
        #expect(!sentence.isEmpty)
    }

    @Test("No suggestion uses clinical, promising or AI wording", arguments: ["en_US", "pt_BR"])
    func plainWords(id: String) {
        let reasons: [FollowUpReason] = [
            .reminder(visitStart: TestClock.now, serviceName: "Glow"),
            .unfinishedVisit(serviceName: "Glow", openSteps: [.photos]),
            .postVisit(visitStart: TestClock.now, serviceName: "Glow"),
            .returnDue(serviceName: "Glow", intervalWeeks: 4, lastVisit: TestClock.now),
            .notBack(daysSinceLastVisit: 70),
            .birthday(date: TestClock.now, isToday: true)
        ]
        let banned = ["AI", "IA", "smart", "intelig", "result", "resultado", "diagnos", "guarante", "garant"]
        for reason in reasons {
            let sentence = text(id).why(reason)
            for word in banned { #expect(!sentence.contains(word), "\(sentence) contains \(word)") }
        }
    }
}
