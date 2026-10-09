//
//  PositionRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PositionRules")
struct PositionRulesTests {
    private func services(_ names: [String]) -> [Service] {
        names.enumerated().map { Service(name: $1, durationMinutes: 30, position: $0) }
    }

    @Test("A new item goes after the last position, and the first one gets zero")
    func nextPosition() {
        #expect(PositionRules.next(after: [Service]()) == 0)
        #expect(PositionRules.next(after: services(["A", "B", "C"])) == 3)
        var gap = services(["A", "B"])
        gap[0].position = 7
        #expect(PositionRules.next(after: gap) == 8, "after the highest, even when positions have gaps")
    }

    @Test("Dragging renumbers the whole list 0 to n-1 in the new order")
    func moving() {
        let list = services(["A", "B", "C", "D"])
        let moved = PositionRules.moving(list, from: IndexSet(integer: 0), to: 3)
        #expect(moved.map(\.name) == ["B", "C", "A", "D"])
        #expect(moved.map(\.position) == [0, 1, 2, 3])
    }

    @Test("onMove's destination is the index before which the item lands, so the last slot is the count")
    func movingToTheEnd() {
        let list = services(["A", "B", "C"])
        #expect(PositionRules.moving(list, from: IndexSet(integer: 0), to: 3).map(\.name) == ["B", "C", "A"])
        #expect(PositionRules.moving(list, from: IndexSet(integer: 2), to: 0).map(\.name) == ["C", "A", "B"])
    }

    @Test("A drag that changes nothing returns the same list")
    func movingNowhere() {
        let list = services(["A", "B", "C"])
        #expect(PositionRules.moving(list, from: IndexSet(integer: 1), to: 1) == list)
        #expect(PositionRules.moving(list, from: IndexSet(integer: 1), to: 2) == list)
    }

    @Test("Only the items whose values changed are written")
    func changedOnly() {
        let before = services(["A", "B", "C", "D"])
        let after = PositionRules.moving(before, from: IndexSet(integer: 1), to: 3)
        #expect(after.map(\.name) == ["A", "C", "B", "D"])
        #expect(PositionRules.changed(from: before, to: after).map(\.name) == ["C", "B"])
        #expect(PositionRules.changed(from: before, to: before).isEmpty)
    }

    @Test("An item that is not in the old list counts as changed")
    func changedNewItem() {
        let before = services(["A"])
        let after = before + [Service(name: "B", durationMinutes: 30, position: 1)]
        #expect(PositionRules.changed(from: before, to: after).map(\.name) == ["B"])
    }
}
