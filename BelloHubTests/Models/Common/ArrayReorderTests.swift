//
//  ArrayReorderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Array reorder")
struct ArrayReorderTests {
    private let letters = ["a", "b", "c", "d"]

    @Test("Moving an element forward lands it before the element that was at the destination")
    func movesForward() {
        #expect(letters.movingElements(at: [0], to: 2) == ["b", "a", "c", "d"])
        #expect(letters.movingElements(at: [0], to: 4) == ["b", "c", "d", "a"])
    }

    @Test("Moving an element back puts it in front of the destination")
    func movesBack() {
        #expect(letters.movingElements(at: [3], to: 1) == ["a", "d", "b", "c"])
        #expect(letters.movingElements(at: [2], to: 0) == ["c", "a", "b", "d"])
    }

    @Test("Several elements move together and keep their order")
    func movesSeveral() {
        #expect(letters.movingElements(at: [0, 1], to: 4) == ["c", "d", "a", "b"])
        #expect(letters.movingElements(at: [1, 3], to: 0) == ["b", "d", "a", "c"])
    }

    @Test("Moving to where it already is changes nothing")
    func movesNowhere() {
        #expect(letters.movingElements(at: [1], to: 1) == letters)
        #expect(letters.movingElements(at: [1], to: 2) == letters)
    }

    @Test("Indices outside the array are ignored and an empty move is a no-op")
    func ignoresBadIndices() {
        #expect(letters.movingElements(at: [], to: 2) == letters)
        #expect(letters.movingElements(at: [9], to: 0) == letters)
        #expect(letters.movingElements(at: [0, 9], to: 4) == ["b", "c", "d", "a"])
        #expect(letters.movingElements(at: [0], to: 99) == ["b", "c", "d", "a"])
    }
}
