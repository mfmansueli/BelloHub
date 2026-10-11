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
        typealias Change = MotionChange.RowChange
        func change(_ old: [Int], _ new: [Int]) -> Change { MotionChange.rowChange(from: old, to: new) }
        #expect(change([1, 2, 3], [1, 2, 3]).isNone)
        #expect(change([1, 2, 3], [1, 2, 3, 4]) == Change(inserted: 1, removed: 0, isReorder: false))
        #expect(change([1, 2, 3], [1, 3]) == Change(inserted: 0, removed: 1, isReorder: false))
        #expect(change([1, 2, 3], [3, 2, 1]) == Change(inserted: 0, removed: 0, isReorder: true))
        #expect(change([1, 2], [3, 4]) == Change(inserted: 2, removed: 2, isReorder: false))
    }

    /// Whether going from `old` to `new` plays an animation, as `motionRows` asks.
    private func animates(
        _ old: [Int]?, _ new: [Int], oldContext: Int = 0, newContext: Int = 0, ready: Bool = true,
        policy: MotionPolicy? = nil
    ) -> Bool {
        let before = old.map { MotionChange.RowSnapshot(ids: $0, context: oldContext) }
        let after = MotionChange.RowSnapshot(ids: new, context: newContext)
        return MotionChange.rowsAnimation(before: before, after: after, isReady: ready, policy: policy ?? normal) != nil
    }

    @Test("A row that is added or removed animates")
    func insertAndRemove() {
        #expect(animates([1, 2, 3], [1, 2, 3, 4]))
        #expect(animates([1, 2, 3], [1, 3]))
    }

    @Test("A load never animates: not ready, or the first list the view sees")
    func loadNeverAnimates() {
        #expect(!animates(nil, Array(1...5)))
        #expect(!animates([], Array(1...5), ready: false))
    }

    @Test("A different context (another day, another filter) is another list and does not animate")
    func contextChange() {
        #expect(!animates([1, 2, 3], [1, 2], oldContext: 1, newContext: 2))
    }

    @Test("Too many changes at once (a sync, an import) do not animate")
    func bulkChangeDoesNotAnimate() {
        let old = Array(1...30)
        #expect(!animates(old, old + Array(100...120)))
        #expect(animates(old, old + Array(100..<(100 + MotionChange.maxAnimatedRowChanges))))
    }

    @Test("Nothing changed means nothing animates, and a reorder animates only in a short list")
    func reorderAndNoChange() {
        #expect(!animates([1, 2, 3], [1, 2, 3]))
        #expect(animates([1, 2, 3], [3, 2, 1]))
        let long = Array(1...(MotionChange.maxAnimatedReorderCount + 1))
        #expect(!animates(long, long.reversed()))
    }

    @Test("UI testing keeps rows instant, Reduce Motion fades them")
    func rowsUnderPolicies() {
        #expect(!animates([1, 2], [1], policy: testing))
        #expect(animates([1, 2], [1], policy: reduced))
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
