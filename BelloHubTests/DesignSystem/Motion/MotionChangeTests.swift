//
//  MotionChangeTests.swift
//  BelloHubTests
//

@testable import BelloHub
import SwiftUI
import Testing

@Suite("MotionChange")
struct MotionChangeTests {
    private let normal = MotionPolicy()
    private let reduced = MotionPolicy(reduceMotion: true)
    private let testing = MotionPolicy(uiTesting: true)

    // MARK: - Which animation

    @Test("Under UI testing nothing animates, whatever the kind", arguments: [
        MotionChange.Kind.number, .rows, .settle, .fade, .slide
    ])
    func uiTestingIsInstant(kind: MotionChange.Kind) {
        #expect(MotionChange.animation(kind, policy: testing) == nil)
    }

    @Test("Normally every change animates", arguments: [
        MotionChange.Kind.number, .rows, .settle, .fade, .slide
    ])
    func normalAnimates(kind: MotionChange.Kind) {
        #expect(MotionChange.animation(kind, policy: normal) != nil)
    }

    @Test("With Reduce Motion a block that changes place does not animate, and the rest crossfade")
    func reduceMotionKinds() {
        #expect(MotionChange.animation(.settle, policy: reduced) == nil)
        #expect(MotionChange.animation(.number, policy: reduced) != nil)
        #expect(MotionChange.animation(.rows, policy: reduced) != nil)
        #expect(MotionChange.animation(.slide, policy: reduced) != nil)
    }

    @Test("The change duration is in the band and the reduced fade is at most 0.2 s")
    func durations() {
        #expect((0.18...0.56).contains(Motion.Duration.change))
        #expect(Motion.Duration.reducedFade <= 0.2)
    }

    // MARK: - Numbers

    @Test("Digits roll normally, crossfade with Reduce Motion and change at once in UI tests")
    func numberStyles() {
        #expect(MotionChange.numberStyle(policy: normal) == .rolling)
        #expect(MotionChange.numberStyle(policy: reduced) == .crossfade)
        #expect(MotionChange.numberStyle(policy: testing) == .instant)
    }

    @Test("A value that did not change, or the first one, never animates; a real change does")
    func valueChanges() {
        #expect(!MotionChange.animatesValue(from: nil, to: 3, policy: normal))
        #expect(!MotionChange.animatesValue(from: 3, to: 3, policy: normal))
        #expect(MotionChange.animatesValue(from: 3, to: 4, policy: normal))
        #expect(MotionChange.animatesValue(from: "1 h 20 min", to: "1 h 19 min", policy: reduced))
        #expect(!MotionChange.animatesValue(from: 3, to: 4, policy: testing))
    }

    // MARK: - Rows

    @Test("The change between two lists counts what came, what went and a pure reorder")
    func rowChange() {
        #expect(MotionChange.rowChange(from: [1, 2, 3], to: [1, 2, 3]).isNone)
        #expect(MotionChange.rowChange(from: [1, 2, 3], to: [1, 2, 3, 4]) == .init(inserted: 1, removed: 0, isReorder: false))
        #expect(MotionChange.rowChange(from: [1, 2, 3], to: [1, 3]) == .init(inserted: 0, removed: 1, isReorder: false))
        #expect(MotionChange.rowChange(from: [1, 2, 3], to: [3, 2, 1]) == .init(inserted: 0, removed: 0, isReorder: true))
        #expect(MotionChange.rowChange(from: [1, 2], to: [3, 4]) == .init(inserted: 2, removed: 2, isReorder: false))
    }

    private func snapshot(_ ids: [Int], context: Int = 0) -> MotionChange.RowSnapshot<Int> {
        MotionChange.RowSnapshot(ids: ids, context: context)
    }

    @Test("A row that is added or removed animates")
    func insertAndRemove() {
        let before = snapshot([1, 2, 3])
        #expect(MotionChange.rowsAnimation(before: before, after: snapshot([1, 2, 3, 4]), isReady: true, policy: normal) != nil)
        #expect(MotionChange.rowsAnimation(before: before, after: snapshot([1, 3]), isReady: true, policy: normal) != nil)
    }

    @Test("A load never animates: not ready, or the first list the view sees")
    func loadNeverAnimates() {
        let after = snapshot(Array(1...5))
        #expect(MotionChange.rowsAnimation(before: nil, after: after, isReady: true, policy: normal) == nil)
        #expect(MotionChange.rowsAnimation(before: snapshot([]), after: after, isReady: false, policy: normal) == nil)
    }

    @Test("A different context (another day, another filter) is another list and does not animate")
    func contextChange() {
        let before = snapshot([1, 2, 3], context: 1)
        #expect(MotionChange.rowsAnimation(before: before, after: snapshot([1, 2], context: 2), isReady: true, policy: normal) == nil)
    }

    @Test("Too many changes at once (a sync, an import) do not animate")
    func bulkChangeDoesNotAnimate() {
        let before = snapshot(Array(1...30))
        let after = snapshot(Array(1...30) + Array(100...120))
        #expect(MotionChange.rowsAnimation(before: before, after: after, isReady: true, policy: normal) == nil)
        let atTheLimit = snapshot(Array(1...30) + Array(100..<(100 + MotionChange.maxAnimatedRowChanges)))
        #expect(MotionChange.rowsAnimation(before: before, after: atTheLimit, isReady: true, policy: normal) != nil)
    }

    @Test("Nothing changed means nothing animates, and a reorder animates only in a short list")
    func reorderAndNoChange() {
        let before = snapshot([1, 2, 3])
        #expect(MotionChange.rowsAnimation(before: before, after: before, isReady: true, policy: normal) == nil)
        #expect(MotionChange.rowsAnimation(before: before, after: snapshot([3, 2, 1]), isReady: true, policy: normal) != nil)
        let long = Array(1...(MotionChange.maxAnimatedReorderCount + 1))
        #expect(MotionChange.rowsAnimation(
            before: snapshot(long), after: snapshot(long.reversed()), isReady: true, policy: normal
        ) == nil)
    }

    @Test("UI testing keeps rows instant, Reduce Motion fades them")
    func rowsUnderPolicies() {
        let before = snapshot([1, 2])
        let after = snapshot([1])
        #expect(MotionChange.rowsAnimation(before: before, after: after, isReady: true, policy: testing) == nil)
        #expect(MotionChange.rowsAnimation(before: before, after: after, isReady: true, policy: reduced) != nil)
        #expect(MotionChange.rowStyle(policy: normal) == .slideAndFade)
        #expect(MotionChange.rowStyle(policy: reduced) == .fade)
        #expect(MotionChange.rowStyle(policy: testing) == .none)
    }

    @Test("VoiceOver is told the layout changed only when a row left")
    func layoutChangeAnnouncement() {
        let removed = MotionChange.RowChange(inserted: 0, removed: 1, isReorder: false)
        let added = MotionChange.RowChange(inserted: 1, removed: 0, isReorder: false)
        #expect(MotionChange.postsLayoutChange(removed, voiceOver: true))
        #expect(!MotionChange.postsLayoutChange(removed, voiceOver: false))
        #expect(!MotionChange.postsLayoutChange(added, voiceOver: true))
    }
}
