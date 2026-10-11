//
//  ClientMessageComposerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientMessageComposer")
struct ClientMessageComposerTests {
    private let ana = Client(name: "Ana Costa", createdAt: TestClock.days(-200))

    private func formatters(_ localization: AppLocalization = .en) -> Formatters {
        Formatters(locale: localization.locale, timeZone: TestClock.saoPaulo, currencyCode: "BRL")
    }

    private func text(
        _ kind: ClientMessageRequest.Kind, comeBack: QuickReply? = nil, lastService: String? = nil,
        link: String? = "https://bellohub.app/maria", localization: AppLocalization = .en
    ) -> String {
        let values = ClientMessageComposer.values(for: kind, client: ana, lastServiceName: lastService, link: link)
        return ClientMessageComposer.text(
            for: kind, comeBack: comeBack, values: values, localization: localization,
            formatters: formatters(localization)
        )
    }

    @Test("A follow-up uses the 'Come back soon' wording with the client's first name, the service and the link")
    func followUp() {
        let message = text(.followUp(serviceName: "Glow Facial"))

        #expect(message.contains("Hi Ana!"))
        #expect(message.contains("Glow Facial"))
        #expect(message.contains("\nhttps://bellohub.app/maria"))
        #expect(!message.contains("{"))
    }

    @Test("Her own rewritten reply wins over the built-in wording")
    func ownReply() {
        let own = QuickReply(
            id: BuiltInQuickReply.comeBack.id, builtInKey: "comeBack", title: "Come back soon",
            text: "Ana, miss you! {service} again? {link}", position: 5, updatedAt: TestClock.now
        )

        let winBack = text(.winBack, comeBack: own, lastService: "Peeling")
        #expect(winBack == "Ana, miss you! Peeling again?\nhttps://bellohub.app/maria")
    }

    @Test("A win-back message names the service of the last visit; without one the gap stays visible")
    func winBack() {
        #expect(text(.winBack, lastService: "Peeling").contains("Peeling"))
        #expect(text(.winBack, lastService: nil).contains("{service}"))
    }

    @Test("A follow-up keeps its own service, not the last visit's")
    func followUpService() {
        #expect(text(.followUp(serviceName: "Glow Facial"), lastService: "Peeling").contains("Glow Facial"))
    }

    @Test("Birthday wishes carry only the first name", arguments: AppLocalization.allCases)
    func birthday(localization: AppLocalization) {
        let message = text(.birthday, localization: localization)

        #expect(message.contains("Ana"))
        #expect(!message.contains("Costa"))
        #expect(!message.contains("{"))
    }

    @Test("In a right-to-left language the name is isolated so it cannot reorder the sentence")
    func rightToLeft() {
        let message = text(.birthday, localization: .ar)

        #expect(message.contains(BidiIsolate.wrap("Ana")))
    }

    @Test("The service of the last completed visit is found, and a client with none has no service")
    func lastService() {
        let older = makeVisit(start: TestClock.days(-90), status: .completed, serviceName: "Peeling")
        let newer = makeVisit(start: TestClock.days(-60), status: .completed, serviceName: "Glow Facial")
        let cancelled = makeVisit(start: TestClock.days(-10), status: .cancelled, serviceName: "Lashes")

        #expect(ClientMessageComposer.lastServiceName(in: [older, newer, cancelled]) == "Glow Facial")
        #expect(ClientMessageComposer.lastServiceName(in: [cancelled]) == nil)
    }

    @Test("The log keeps the kind of the message, never its text")
    func logTemplate() {
        #expect(ClientMessageRequest(clientID: ana.id, kind: .followUp(serviceName: "Glow")).logTemplate == "followUp")
        #expect(ClientMessageRequest(clientID: ana.id, kind: .winBack).logTemplate == "winBack")
        #expect(ClientMessageRequest(clientID: ana.id, kind: .birthday).logTemplate == "birthday")
    }
}
