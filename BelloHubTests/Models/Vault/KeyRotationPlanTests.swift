//
//  KeyRotationPlanTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

@MainActor
@Suite("KeyRotationPlan")
struct KeyRotationPlanTests {
    @Test("A fresh plan is generation 1 with nothing retired")
    func fresh() {
        let plan = KeyRotationPlan()
        #expect(plan.currentGeneration == 1)
        #expect(plan.retiredGenerations.isEmpty)
        #expect(plan.openableGenerations == [1])
        #expect(plan.canOpen(generation: 1))
        #expect(!plan.canOpen(generation: 2))
    }

    @Test("Rotating moves to the next generation and keeps the old one openable until it is retired")
    func rotate() {
        let rotated = KeyRotationPlan().rotated().rotated()
        #expect(rotated.currentGeneration == 3)
        #expect(rotated.retiredGenerations == [1, 2])
        #expect(rotated.openableGenerations == [1, 2, 3])

        let retired = rotated.retiring(1)
        #expect(retired.openableGenerations == [2, 3])
        #expect(retired.retiring(3).currentGeneration == 3, "the current one cannot be retired")
        #expect(retired.retiring(3).openableGenerations == [2, 3])
    }

    @Test("Nothing goes below generation 1 and retired lists never hold the current or later generations")
    func invariants() {
        let plan = KeyRotationPlan(currentGeneration: 0, retiredGenerations: [0, 5, 2, 2])
        #expect(plan.currentGeneration == 1)
        #expect(plan.retiredGenerations.isEmpty)
        let later = KeyRotationPlan(currentGeneration: 4, retiredGenerations: [3, 1, 9, 4])
        #expect(later.retiredGenerations == [1, 3])
    }

    @Test("The plan round-trips through JSON and every openable generation derives a distinct inbox key")
    func codableAndKeys() throws {
        let plan = KeyRotationPlan().rotated()
        let decoded = try JSONDecoder().decode(KeyRotationPlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded == plan)

        let manager = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        try manager.prepare(createIfMissing: false)
        let keys = try plan.openableGenerations.map { try manager.inboxPrivateKey(generation: $0).rawRepresentation }
        #expect(Set(keys).count == 2, "generation 1 and 2 are different keys from the same seed")
    }
}
