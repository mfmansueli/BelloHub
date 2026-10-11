//
//  DaySlideTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

@Suite("DaySlide")
struct DaySlideTests {
    private let monday = Date(timeIntervalSince1970: 1_790_000_000)
    private var tuesday: Date { monday.addingTimeInterval(86_400) }

    @Test("Going to a later day is forward, to an earlier one backward, to the same one no travel")
    func travel() {
        #expect(DaySlide.travel(from: monday, to: tuesday) == .forward)
        #expect(DaySlide.travel(from: tuesday, to: monday) == .backward)
        #expect(DaySlide.travel(from: monday, to: monday) == .none)
    }

    @Test("Forward comes from the trailing edge and backward from the leading edge in left-to-right layouts")
    func leftToRight() {
        let policy = MotionPolicy()
        #expect(DaySlide.startOffset(.forward, layoutDirection: .leftToRight, policy: policy) == Motion.slideOffset)
        #expect(DaySlide.startOffset(.backward, layoutDirection: .leftToRight, policy: policy) == -Motion.slideOffset)
        #expect(DaySlide.startOffset(.none, layoutDirection: .leftToRight, policy: policy) == 0)
    }

    @Test("In right-to-left layouts the direction mirrors")
    func rightToLeft() {
        let policy = MotionPolicy()
        #expect(DaySlide.startOffset(.forward, layoutDirection: .rightToLeft, policy: policy) == -Motion.slideOffset)
        #expect(DaySlide.startOffset(.backward, layoutDirection: .rightToLeft, policy: policy) == Motion.slideOffset)
    }

    @Test("Reduce Motion and UI testing never offset the content", arguments: [
        MotionPolicy(reduceMotion: true), MotionPolicy(uiTesting: true)
    ])
    func restricted(policy: MotionPolicy) {
        for travel in [DaySlide.Travel.forward, .backward, .none] {
            #expect(DaySlide.startOffset(travel, layoutDirection: .leftToRight, policy: policy) == 0)
            #expect(DaySlide.startOffset(travel, layoutDirection: .rightToLeft, policy: policy) == 0)
        }
    }
}
