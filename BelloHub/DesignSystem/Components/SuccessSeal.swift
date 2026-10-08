//
//  SuccessSeal.swift
//  BelloHub
//

import SwiftUI

/// The success moment (docs/09-MOTION.md section 3.6): a circle pops (scale 0.45, 1.09, 1) after 0.1 s,
/// the check draws after 0.38 s, one ring expands after 0.45 s, and a success haptic plays at the peak.
/// With Reduce Motion the seal appears finished, with the check drawn and no ring.
struct SuccessSeal: View {
    enum Tone {
        case sage
        case graphite
    }

    var size: CGFloat = 72
    var tone: Tone = .sage
    @Environment(\.motionPolicy) private var policy
    @State private var circleShown = false
    @State private var checkProgress: CGFloat = 0
    @State private var ringExpanded = false

    var body: some View {
        ZStack {
            Circle().strokeBorder(ringColor, lineWidth: 2)
                .scaleEffect(ringExpanded ? 1.7 : 0.9)
                .opacity(ringExpanded ? 0 : (policy.allowsMovement ? 0.55 : 0))
            Circle().fill(fill)
                .overlay { Circle().strokeBorder(ringColor, lineWidth: 2) }
                .scaleEffect(circleShown ? 1 : 0.45)
                .opacity(circleShown ? 1 : 0)
            CheckShape()
                .trim(from: 0, to: checkProgress)
                .stroke(checkColor, style: StrokeStyle(lineWidth: size * 0.046, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .sensoryFeedback(.success, trigger: circleShown) { _, shown in shown }
        .onAppear(perform: play)
        .accessibilityHidden(true)
    }

    private func play() {
        guard !circleShown else { return }
        guard policy.allowsMovement else {
            circleShown = true
            checkProgress = 1
            ringExpanded = true
            return
        }
        withAnimation(Motion.soft().delay(0.1)) { circleShown = true }
        withAnimation(Motion.ease(Motion.Duration.draw).delay(0.38)) { checkProgress = 1 }
        withAnimation(Motion.ease(Motion.Duration.ring).delay(0.45)) { ringExpanded = true }
    }

    private var fill: Color {
        tone == .sage ? Palette.sageWash : Color(hex: 0x242321)
    }

    private var ringColor: Color {
        tone == .sage ? Palette.sage : HeroPalette.glowRose
    }

    private var checkColor: Color {
        tone == .sage ? Palette.sageText : HeroPalette.ink
    }
}

/// The check on a 24 pt grid: `M5 12.5 L9.5 17 L19 7.5`.
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 24
        var path = Path()
        path.move(to: CGPoint(x: 5 * scale, y: 12.5 * scale))
        path.addLine(to: CGPoint(x: 9.5 * scale, y: 17 * scale))
        path.addLine(to: CGPoint(x: 19 * scale, y: 7.5 * scale))
        return path
    }
}
