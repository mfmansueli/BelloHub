//
//  MessageDispatchPlanTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("MessageDispatchPlan")
struct MessageDispatchPlanTests {
    private let phone = "+5511981234410"

    private func channels(_ plan: MessageDispatchPlan) -> [MessageChannel] {
        plan.attempts.map(\.channel)
    }

    @Test("With a number: WhatsApp first, then Messages, and the share sheet always last")
    func withANumber() {
        let plan = MessageDispatchPlan.make(phoneE164: phone, text: "Hi")

        #expect(channels(plan) == [.whatsapp, .sms, .share])
    }

    @Test("Where people text, Messages comes first")
    func textingRegions() {
        let plan = MessageDispatchPlan.make(phoneE164: phone, text: "Hi", preferred: .messages)

        #expect(channels(plan) == [.sms, .whatsapp, .share])
    }

    @Test("Without a usable number only the share sheet is left", arguments: [nil, "", "11981234410"] as [String?])
    func withoutANumber(phone: String?) {
        #expect(channels(MessageDispatchPlan.make(phoneE164: phone, text: "Hi")) == [.share])
    }

    @Test("Both links carry the same text")
    func sameText() throws {
        let plan = MessageDispatchPlan.make(phoneE164: phone, text: "Hi Ana")
        let urls = plan.attempts.compactMap { attempt -> URL? in
            switch attempt {
            case .whatsApp(let url), .sms(let url): url
            case .share: nil
            }
        }

        #expect(urls.count == 2)
        #expect(urls.allSatisfy { $0.absoluteString.contains("Hi%20Ana") })
    }
}
