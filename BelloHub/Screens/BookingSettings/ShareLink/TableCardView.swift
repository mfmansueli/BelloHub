//
//  TableCardView.swift
//  BelloHub
//

import SwiftUI

/// The printable card with her QR code: a title, the code, the link and a line saying what to do. It is drawn for
/// paper, so it always uses the light appearance, and it is turned into an image (`TableCardRenderer`) that she
/// shares or prints.
struct TableCardView: View {
    let title: String
    let subtitle: String
    let displayLink: String
    let qr: CGImage

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text(verbatim: title)
                .font(Typography.title)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Image(decorative: qr, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 320, height: 320)
            VStack(spacing: Spacing.xs) {
                Text(verbatim: displayLink).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 420)
        .background(Palette.surface)
        .environment(\.colorScheme, .light)
    }
}
