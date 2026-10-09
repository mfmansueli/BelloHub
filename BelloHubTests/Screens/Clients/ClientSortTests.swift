//
//  ClientSortTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientSort")
struct ClientSortTests {
    private func sorted(_ names: [String]) -> [String] {
        ClientSort.sorted(names.map { makeListedClient(name: $0) }).map(\.name)
    }

    @Test("Names sort the way people read them: accents and case do not push a name to the end")
    func readingOrder() {
        #expect(sorted(["Zoe", "María", "ana", "Beatriz"]) == ["ana", "Beatriz", "María", "Zoe"])
    }

    @Test("Numbers inside names sort by value: Ana 2 comes before Ana 10")
    func numbersByValue() {
        #expect(sorted(["Ana 10", "Ana 2", "Ana 1"]) == ["Ana 1", "Ana 2", "Ana 10"])
    }

    @Test("Two clients with the same name keep the same order every time")
    func tiesAreStable() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let first = makeListedClient(id: firstID, name: "Ana")
        let second = makeListedClient(id: secondID, name: "Ana")

        #expect(ClientSort.sorted([second, first]).map(\.id) == [first.id, second.id])
        #expect(ClientSort.sorted([first, second]).map(\.id) == [first.id, second.id])
    }
}
