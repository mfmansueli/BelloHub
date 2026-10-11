//
//  LaunchMotionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("LaunchOptions motion switches")
struct LaunchMotionTests {
    @Test("A UI test launch is instant, and -uiAnimate keeps the animations on")
    func animate() {
        #expect(LaunchOptions(arguments: ["-uiTesting"]).isMotionOff)
        #expect(!LaunchOptions(arguments: ["-uiTesting", "-uiAnimate"]).isMotionOff)
        #expect(!LaunchOptions(arguments: []).isMotionOff)
    }

    @Test("-uiReduceMotion stands still even when the animations were asked for")
    func reduceMotionWins() {
        #expect(LaunchOptions(arguments: ["-uiTesting", "-uiReduceMotion"]).isMotionOff)
        #expect(LaunchOptions(arguments: ["-uiTesting", "-uiAnimate", "-uiReduceMotion"]).isMotionOff)
    }
}
