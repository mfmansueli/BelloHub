//
//  FramingGuides.swift
//  BelloHub
//

import SwiftUI

/// Thin rule-of-thirds lines over the camera preview while a framing reference shows (routine item 11): with the
/// earlier photo underneath they make "same position" concrete (the eyes on the upper line, the face centred). Drawn
/// with `ivory`, which reads on any picture behind it; decorative, so hidden from VoiceOver.
struct FramingGuides: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                for fraction in [1.0 / 3, 2.0 / 3] {
                    path.move(to: CGPoint(x: width * fraction, y: 0))
                    path.addLine(to: CGPoint(x: width * fraction, y: height))
                    path.move(to: CGPoint(x: 0, y: height * fraction))
                    path.addLine(to: CGPoint(x: width, y: height * fraction))
                }
            }
            .stroke(Palette.ivory, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
