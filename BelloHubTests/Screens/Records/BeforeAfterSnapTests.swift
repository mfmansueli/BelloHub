//
//  BeforeAfterSnapTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("BeforeAfterSnap")
struct BeforeAfterSnapTests {
    @Test("Close to an end the handle settles on it", arguments: [(0.0, 0.0), (0.05, 0.0), (0.95, 1.0), (1.0, 1.0)])
    func ends(input: Double, expected: Double) {
        #expect(BeforeAfterSnap.settled(input) == expected)
    }

    @Test("Close to the middle it settles on the half", arguments: [0.47, 0.5, 0.53])
    func middle(input: Double) {
        #expect(BeforeAfterSnap.settled(input) == 0.5)
    }

    @Test("Anywhere else it stays where she left it", arguments: [0.1, 0.3, 0.42, 0.58, 0.8, 0.9])
    func stays(input: Double) {
        #expect(BeforeAfterSnap.settled(input) == input)
    }

    @Test("A value outside the range is brought back to it")
    func clamps() {
        #expect(BeforeAfterSnap.settled(-0.4) == 0)
        #expect(BeforeAfterSnap.settled(1.7) == 1)
    }
}
