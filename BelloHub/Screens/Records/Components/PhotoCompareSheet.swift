//
//  PhotoCompareSheet.swift
//  BelloHub
//

import SwiftUI

/// Two photos she picked, from the same visit or from different ones, side by side or under a slider. Each side is
/// named by its kind and day, so a comparison across visits reads correctly. Full images are decrypted only here.
struct PhotoCompareSheet: View {
    let first: Photo
    let second: Photo
    let formatters: Formatters
    let load: (Photo) async -> PhotoData?

    @State private var mode = BeforeAfterCompareView.Mode.sideBySide
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Picker(selection: $mode) {
                        Text("recordHistory.compare.sideBySide").tag(BeforeAfterCompareView.Mode.sideBySide)
                        Text("recordHistory.compare.sliderMode").tag(BeforeAfterCompareView.Mode.slider)
                    } label: {
                        Text("recordHistory.compare.mode")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("photoCompare.mode")
                    BeforeAfterCompareView(
                        pair: BeforeAfterPair(before: first, after: second), mode: mode, load: load,
                        leadingTitle: title(first), trailingTitle: title(second)
                    )
                    FooterNote(text: "recordHistory.photos.private", icon: .lock)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text("photoCompare.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("common.done") }
                        .accessibilityIdentifier("photoCompare.done")
                }
            }
        }
        .presentationBackground(Palette.bg)
    }

    private func title(_ photo: Photo) -> Text {
        Text(verbatim: "\(photo.kind.title.resolved(in: locale)) · \(formatters.shortDate(photo.takenAt))")
    }
}
