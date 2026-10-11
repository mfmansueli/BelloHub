//
//  InlineCheck.swift
//  BelloHub
//

import SwiftUI

/// The small confirmation that fits next to a label or a line of text: the seal's check, drawn in 0.5 s, with a
/// success haptic. For where a full `SuccessSeal` would be too much (a "Saved" line, the label of a button that just
/// finished). With Reduce Motion the check is drawn at once; the haptic stays. Decorative: the text beside it says
/// what happened.
struct InlineCheck: View {
    var size: CGFloat = 18
    /// The stroke: sage text on the page, `onAction` on the primary button.
    var color = Palette.sageText
    var plays = true
    @Environment(\.motionPolicy) private var policy
    @State private var progress: CGFloat = 0

    var body: some View {
        CheckShape()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .sensoryFeedback(.success, trigger: progress) { _, new in plays && new == 1 }
            .onAppear(perform: draw)
            .accessibilityHidden(true)
    }

    private func draw() {
        guard progress == 0 else { return }
        let duration = ConfirmationCue.inlineDrawDuration(policy: policy)
        if duration > 0 {
            withAnimation(Motion.ease(duration)) { progress = 1 }
        } else {
            progress = 1
        }
    }
}

#Preview {
    HStack { InlineCheck(); Text(verbatim: "Saved") }.padding()
}
