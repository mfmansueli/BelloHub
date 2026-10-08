//
//  HeroSurface.swift
//  BelloHub
//

import SwiftUI

/// The graphite hero surface: a 160 degree gradient with two radial glows (rose from the top
/// trailing corner, sage from the bottom leading corner). With `isAnimated` the glows drift slowly and
/// a sheen crosses the card once (docs/09-MOTION.md section 3.7). The drift runs only while the view is on
/// screen and the scene is active, stops after 60 s, and never runs with Reduce Motion or Low Power Mode.
struct HeroSurface: View {
    var isAnimated = false
    @Environment(\.motionPolicy) private var policy
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var appearedAt: Date?
    @State private var sheenDone = false

    private static let driftLimit: TimeInterval = 60

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isDrifting)) { context in
            let drift = driftValue(at: context.date)
            ZStack {
                LinearGradient(
                    colors: [HeroPalette.gradientStart, HeroPalette.gradientEnd],
                    startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1)
                )
                glow(HeroPalette.glowRose, opacity: HeroPalette.glowRoseOpacity, corner: .topTrailing, drift: drift)
                glow(HeroPalette.glowSage, opacity: HeroPalette.glowSageOpacity, corner: .bottomLeading, drift: -drift)
                sheen
            }
        }
        .onAppear { appearedAt = appearedAt ?? .now }
        .accessibilityHidden(true)
    }

    private var isDrifting: Bool {
        isAnimated && policy.allowsAmbient && scenePhase == .active && !hasStopped(at: .now)
    }

    private func hasStopped(at date: Date) -> Bool {
        guard let appearedAt else { return false }
        return date.timeIntervalSince(appearedAt) > Self.driftLimit
    }

    /// -1 to 1, a sine over the 28 s period (14 s each way).
    private func driftValue(at date: Date) -> CGFloat {
        guard isDrifting, let appearedAt else { return 0 }
        let elapsed = date.timeIntervalSince(appearedAt)
        return CGFloat(sin(elapsed * 2 * .pi / (Motion.Duration.glow * 2)))
    }

    private func glow(_ color: Color, opacity: Double, corner: Alignment, drift: CGFloat) -> some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height) * 0.9
            RadialGradient(
                colors: [color.opacity(opacity), color.opacity(0)],
                center: .center, startRadius: 0, endRadius: side / 2
            )
            .frame(width: side, height: side)
            .scaleEffect(1 + 0.06 * (drift + 1))
            .directionalOffset(x: drift * proxy.size.width * 0.06, y: drift * proxy.size.height * 0.05)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: corner)
            .offset(x: corner == .topTrailing ? side * 0.25 : -side * 0.25,
                    y: corner == .topTrailing ? -side * 0.25 : side * 0.25)
        }
    }

    @ViewBuilder
    private var sheen: some View {
        if isAnimated && policy.allowsMovement {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.11), .clear], startPoint: .leading, endPoint: .trailing
                )
                    .frame(width: proxy.size.width * 0.34)
                    .rotationEffect(.degrees(-18))
                    .directionalOffset(x: sheenDone ? proxy.size.width * 1.2 : -proxy.size.width * 0.5)
                    .opacity(sheenDone ? 0 : 1)
                    .task {
                        withAnimation(.easeInOut(duration: Motion.Duration.sheen).delay(0.55)) { sheenDone = true }
                    }
            }
        }
    }
}
