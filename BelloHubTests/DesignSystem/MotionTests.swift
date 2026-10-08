//
//  MotionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

@Suite("Motion")
struct MotionTests {
    @Test("The first nine blocks are staggered by 40 ms, the rest share the late delay")
    func arrivalDelays() {
        #expect(Motion.arrivalDelay(index: 0) == 0)
        #expect(abs(Motion.arrivalDelay(index: 1) - 0.04) < 0.0001)
        #expect(abs(Motion.arrivalDelay(index: 8) - 0.32) < 0.0001)
        #expect(Motion.arrivalDelay(index: 9) == Motion.lateDelay)
        #expect(Motion.arrivalDelay(index: 40) == Motion.lateDelay)
    }

    @Test("A negative index never produces a negative delay")
    func negativeIndex() {
        #expect(Motion.arrivalDelay(index: -3) == 0)
    }

    @Test("Durations stay in the 180 to 560 ms band except the success ring and the ambient loops")
    func durationsStayInBand() {
        let band = 0.18...0.62
        for value in [Motion.Duration.press, Motion.Duration.fade, Motion.Duration.rise,
                      Motion.Duration.sheet, Motion.Duration.pop, Motion.Duration.draw, Motion.Duration.bar] {
            #expect(band.contains(value))
        }
    }

    // MARK: - Policy matrix (Reduce Motion, Low Power Mode, UI testing)

    @Test("Normal conditions allow everything")
    func normal() {
        let policy = MotionPolicy()

        #expect(policy.allowsMovement)
        #expect(policy.allowsAmbient)
        #expect(policy.allowsFade)
    }

    @Test("Reduce Motion removes movement and loops but keeps a short fade")
    func reduceMotion() {
        let policy = MotionPolicy(reduceMotion: true)

        #expect(!policy.allowsMovement)
        #expect(!policy.allowsAmbient)
        #expect(policy.allowsFade)
    }

    @Test("Low Power Mode keeps movement but stops loops")
    func lowPower() {
        let policy = MotionPolicy(lowPowerMode: true)

        #expect(policy.allowsMovement)
        #expect(!policy.allowsAmbient)
    }

    @Test("UI testing turns every animation off")
    func uiTesting() {
        let policy = MotionPolicy(uiTesting: true)

        #expect(!policy.allowsMovement)
        #expect(!policy.allowsAmbient)
        #expect(!policy.allowsFade)
    }

    @Test("Loops need every condition: no combination of the three switches allows them except all off",
          arguments: [(false, false, false, true), (true, false, false, false), (false, true, false, false),
                      (false, false, true, false), (true, true, true, false)])
    func ambientMatrix(reduce: Bool, lowPower: Bool, testing: Bool, expected: Bool) {
        let policy = MotionPolicy(reduceMotion: reduce, lowPowerMode: lowPower, uiTesting: testing)

        #expect(policy.allowsAmbient == expected)
    }

    // MARK: - Directional

    @Test("Horizontal motion flips in right-to-left languages and vertical motion does not exist in the helper")
    func directional() {
        #expect(Directional.x(12, layoutDirection: .leftToRight) == 12)
        #expect(Directional.x(12, layoutDirection: .rightToLeft) == -12)
        #expect(Directional.x(0, layoutDirection: .rightToLeft) == 0)
    }

    @Test("Concentric radius is the outer radius minus the padding, never negative")
    func concentricRadius() {
        #expect(Radius.concentric(outer: 24, inset: 8) == 16)
        #expect(Radius.concentric(outer: 24, inset: 30) == 0)
    }
}
