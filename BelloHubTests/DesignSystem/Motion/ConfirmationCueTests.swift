//
//  ConfirmationCueTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("ConfirmationCue and CaptureFlash")
struct ConfirmationCueTests {
    @Test("A count that goes up confirms; the same count or a lower one does not")
    func counts() {
        #expect(ConfirmationCue.fires(countFrom: 0, to: 1))
        #expect(ConfirmationCue.fires(countFrom: 3, to: 5))
        #expect(!ConfirmationCue.fires(countFrom: 2, to: 2))
        #expect(!ConfirmationCue.fires(countFrom: 3, to: 2))
    }

    @Test("A flag that turns on confirms; staying on, turning off or staying off do not")
    func flags() {
        #expect(ConfirmationCue.fires(flagFrom: false, to: true))
        #expect(!ConfirmationCue.fires(flagFrom: true, to: true))
        #expect(!ConfirmationCue.fires(flagFrom: true, to: false))
        #expect(!ConfirmationCue.fires(flagFrom: false, to: false))
    }

    @Test("The seal pops normally and appears finished with Reduce Motion, in UI tests too")
    func sealStyle() {
        #expect(ConfirmationCue.sealStyle(policy: MotionPolicy()) == .pop)
        #expect(ConfirmationCue.sealStyle(policy: MotionPolicy(reduceMotion: true)) == .settled)
        #expect(ConfirmationCue.sealStyle(policy: MotionPolicy(uiTesting: true)) == .settled)
    }

    @Test("The inline check draws in half a second, and at once with Reduce Motion")
    func inlineCheck() {
        #expect(ConfirmationCue.inlineDrawDuration(policy: MotionPolicy()) == 0.5)
        #expect(ConfirmationCue.inlineDrawDuration(policy: MotionPolicy(reduceMotion: true)) == 0)
        #expect(ConfirmationCue.inlineDrawDuration(policy: MotionPolicy(uiTesting: true)) == 0)
    }

    @Test("The brief seal stays long enough to read and never blocks: it is under two seconds")
    func hold() {
        #expect(ConfirmationCue.sealHold < 2)
        #expect(ConfirmationCue.sealHold > 1)
    }

    @Test("The capture flash is 20 percent white for 0.12 s, and none with Reduce Motion or in UI tests")
    func captureFlash() {
        #expect(CaptureFlash.peakOpacity(policy: MotionPolicy()) == 0.2)
        #expect(CaptureFlash.duration(policy: MotionPolicy()) == 0.12)
        #expect(CaptureFlash.peakOpacity(policy: MotionPolicy(reduceMotion: true)) == 0)
        #expect(CaptureFlash.peakOpacity(policy: MotionPolicy(uiTesting: true)) == 0)
    }
}
