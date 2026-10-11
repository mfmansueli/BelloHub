//
//  KnowledgeListRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("KnowledgeListRules")
struct KnowledgeListRulesTests {
    @Test("An entry is trimmed and added at the end")
    func adds() {
        let result = KnowledgeListRules.adding("  Fragrance-free ", to: ["Quiet room"])

        #expect(result == .added(["Quiet room", "Fragrance-free"]))
    }

    @Test("Spaces alone add nothing")
    func empty() {
        #expect(KnowledgeListRules.adding("   ", to: ["Quiet room"]) == .empty)
        #expect(KnowledgeListRules.adding("", to: []) == .empty)
    }

    @Test("An entry the list already says is not repeated, whatever its case or accents")
    func duplicates() {
        #expect(KnowledgeListRules.adding("quiet ROOM", to: ["Quiet room"]) == .duplicate)
        #expect(KnowledgeListRules.adding("Pressão leve", to: ["pressao leve"]) == .duplicate)
    }

    @Test("Removing takes out exactly the chosen rows")
    func removing() {
        #expect(KnowledgeListRules.removing(IndexSet([0, 2]), from: ["a", "b", "c", "d"]) == ["b", "d"])
        #expect(KnowledgeListRules.removing(IndexSet([9]), from: ["a"]) == ["a"])
    }

    @Test("Moving follows the system's onMove: the row lands before the one that was at the destination")
    func moving() {
        let list = ["a", "b", "c", "d"]

        #expect(KnowledgeListRules.moving(IndexSet([0]), to: 3, in: list) == ["b", "c", "a", "d"])
        #expect(KnowledgeListRules.moving(IndexSet([0]), to: 4, in: list) == ["b", "c", "d", "a"])
        #expect(KnowledgeListRules.moving(IndexSet([3]), to: 1, in: list) == ["a", "d", "b", "c"])
        #expect(KnowledgeListRules.moving(IndexSet([3]), to: 0, in: list) == ["d", "a", "b", "c"])
        #expect(KnowledgeListRules.moving(IndexSet([1]), to: 1, in: list) == list)
        #expect(KnowledgeListRules.moving(IndexSet([1]), to: 2, in: list) == list)
    }

    @Test("Moving two rows together keeps their order")
    func movingMany() {
        #expect(KnowledgeListRules.moving(IndexSet([0, 1]), to: 4, in: ["a", "b", "c", "d"]) == ["c", "d", "a", "b"])
    }
}
