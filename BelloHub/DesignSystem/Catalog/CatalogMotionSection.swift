//
//  CatalogMotionSection.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Replays the motion kit on demand: the arrival stagger and the success seal.
struct CatalogMotionSection: View {
    @State private var replay = 0

    var body: some View {
        CatalogSection(title: "Motion", identifier: "catalog.section.motion") {
            Button { replay += 1 } label: { Text(verbatim: "Replay") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("catalog.motion.replay")
            HStack(spacing: Spacing.lg) {
                SuccessSeal(size: 72, tone: .sage).id(replay)
                SuccessSeal(size: 64, tone: .graphite).id(replay)
            }
            StaggeredStack(spacing: Spacing.sm) {
                ForEach(0..<4, id: \.self) { index in
                    Text(verbatim: "Block \(index + 1)")
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.control,
                                                                          style: .continuous))
                }
            }
            .id(replay)
        }
    }
}
#endif
