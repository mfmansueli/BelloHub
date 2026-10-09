//
//  NoShowCountMessageTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("NoShowCountMessage")
struct NoShowCountMessageTests {
    private func message(counted: Int, limit: Int = 3, on: Bool = true, action: NoShowAction = .tell)
        -> NoShowCountMessage {
        var policy = NoShowPolicy.standard
        policy.limit = limit
        policy.action = action
        policy.isOn = on
        return NoShowCountMessage.make(
            status: NoShowStatus(counted: counted, limit: limit, isProtectionOn: on), policy: policy
        )
    }

    @Test("Protection off says so, whatever the count")
    func off() {
        #expect(message(counted: 5, on: false) == .protectionOff)
    }

    @Test("Under the limit it says how many are left")
    func under() {
        #expect(message(counted: 0) == .counting(counted: 0, limit: 3, remaining: 3, months: 12))
        #expect(message(counted: 2) == .counting(counted: 2, limit: 3, remaining: 1, months: 12))
        #expect(!message(counted: 2).isAlert)
    }

    @Test("At the limit it names the rule's action", arguments: NoShowAction.allCases)
    func reached(action: NoShowAction) {
        let result = message(counted: 3, action: action)

        #expect(result == .limitReached(action: action, months: 12))
        #expect(result.isAlert)
    }

    @Test("Past the limit still reads as reached")
    func past() {
        #expect(message(counted: 4).isAlert)
    }
}
