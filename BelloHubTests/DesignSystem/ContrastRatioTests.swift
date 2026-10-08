//
//  ContrastRatioTests.swift
//  BelloHubTests
//

import Testing
import UIKit

@Suite("ContrastRatio")
struct ContrastRatioTests {
    @Test("Black on white is the maximum, 21:1")
    func blackOnWhiteIsMaximum() {
        let ratio = ContrastRatio.between(.black, .white)

        #expect(abs(ratio - 21) < 0.01)
    }

    @Test("Identical colors are the minimum, 1:1")
    func identicalColorsAreMinimum() {
        let ratio = ContrastRatio.between(.systemBlue, .systemBlue)

        #expect(abs(ratio - 1) < 0.0001)
    }

    @Test("The ratio does not depend on argument order")
    func orderDoesNotMatter() {
        let forward = ContrastRatio.between(.black, .systemYellow)
        let backward = ContrastRatio.between(.systemYellow, .black)

        #expect(forward == backward)
    }
}
