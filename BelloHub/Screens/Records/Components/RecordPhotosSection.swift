//
//  RecordPhotosSection.swift
//  BelloHub
//

import SwiftUI

/// The photos part of 4.7: the latest visit's before and after to compare, and every photo on a timeline. A tap on a
/// photo opens it, where she sets who can see it.
struct RecordPhotosSection: View {
    let pairs: [BeforeAfterPair]
    let timeline: [Photo]
    let formatters: Formatters
    let load: (Photo) async -> PhotoData?
    let onOpen: (Photo) -> Void

    @State private var mode = BeforeAfterCompareView.Mode.sideBySide
    @State private var selectedPairID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("recordHistory.photos.title").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if timeline.isEmpty {
                Text("recordHistory.photos.empty").font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("recordHistory.photos.empty")
            } else {
                if let pair = selectedPair { compare(pair) }
                timelineStrip
            }
            FooterNote(text: "recordHistory.photos.private", icon: .lock)
        }
        .accessibilityIdentifier("recordHistory.photos")
    }

    // MARK: - Compare

    private var selectedPair: BeforeAfterPair? {
        pairs.first { $0.id == selectedPairID } ?? pairs.first
    }

    private func compare(_ pair: BeforeAfterPair) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Picker(selection: $mode) {
                Text("recordHistory.compare.sideBySide").tag(BeforeAfterCompareView.Mode.sideBySide)
                Text("recordHistory.compare.sliderMode").tag(BeforeAfterCompareView.Mode.slider)
            } label: {
                Text("recordHistory.compare.mode")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("recordHistory.compare.mode")
            if pairs.count > 1 {
                Picker(selection: Binding(get: { pair.id }, set: { selectedPairID = $0 })) {
                    ForEach(pairs) { option in
                        Text(verbatim: formatters.shortDate(option.after.takenAt)).tag(option.id)
                    }
                } label: {
                    Text("recordHistory.compare.visit")
                }
                .pickerStyle(.menu)
                .tint(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
                .accessibilityIdentifier("recordHistory.compare.visit")
            }
            BeforeAfterCompareView(pair: pair, mode: mode, load: load)
        }
        .padding(Spacing.md)
        .belloCard()
        .accessibilityIdentifier("recordHistory.compare")
    }

    // MARK: - Timeline

    private var timelineStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Spacing.row) {
                ForEach(timeline) { photo in
                    Button { onOpen(photo) } label: { thumbnail(photo) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recordHistory.photo.\(photo.id.uuidString)")
                }
            }
        }
        .accessibilityIdentifier("recordHistory.timeline")
    }

    private func thumbnail(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Color.clear
                .frame(width: 96, height: 128)
                .overlay { RecordPhotoImage(photo: photo, load: load) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            Text(photo.kind.title).font(Typography.footnoteStrong).foregroundStyle(Palette.ink)
            Text(verbatim: formatters.shortDate(photo.takenAt)).font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
        .frame(width: 96, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
