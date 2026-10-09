//
//  BeforeAfterCompareView.swift
//  BelloHub
//

import SwiftUI

/// A "before" and an "after" photo of one visit, side by side or under a slider that moves between them. The slider is
/// the system's own, so it is adjustable with VoiceOver and Switch Control.
struct BeforeAfterCompareView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case sideBySide
        case slider

        var id: String { rawValue }
    }

    let pair: BeforeAfterPair
    let mode: Mode
    let load: (Photo) async -> PhotoData?

    @State private var fraction = 0.5
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        switch mode {
        case .sideBySide: sideBySide
        case .slider: slider
        }
    }

    // MARK: - Side by side

    private var sideBySide: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            cell(pair.before, title: "treatmentFlow.photos.before")
            cell(pair.after, title: "treatmentFlow.photos.after")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordHistory.compare.sideBySide")
    }

    private func cell(_ photo: Photo, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            frame(for: photo)
            Text(title).font(Typography.metaStrong).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }

    private func frame(for photo: Photo) -> some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay { RecordPhotoImage(photo: photo, useThumbnail: false, load: load) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    // MARK: - Slider

    private var slider: some View {
        VStack(spacing: Spacing.sm) {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { RecordPhotoImage(photo: pair.after, useThumbnail: false, load: load) }
                .overlay {
                    GeometryReader { proxy in
                        RecordPhotoImage(photo: pair.before, useThumbnail: false, load: load)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: proxy.size.width * fraction)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            HStack {
                Text("treatmentFlow.photos.before").font(Typography.metaStrong).foregroundStyle(Palette.ink)
                Spacer()
                Text("treatmentFlow.photos.after").font(Typography.metaStrong).foregroundStyle(Palette.ink)
            }
            .accessibilityHidden(true)
            Slider(value: $fraction, in: 0...1)
                .tint(Palette.sage)
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityLabel(Text("recordHistory.compare.slider"))
                .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
                .accessibilityIdentifier("recordHistory.compare.slider")
        }
    }
}
