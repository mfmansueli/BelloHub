//
//  ClientPhotosSection.swift
//  BelloHub
//

import SwiftUI

/// "Photos": every photo of the client, grouped by the visit it belongs to and named by that visit's day and service.
/// A kind filter narrows them; "Compare" lets her pick any two, from the same visit or from different ones, and opens
/// them side by side. Photos stay private unless she shared one; nothing here changes who can see them.
struct ClientPhotosSection: View {
    let timeline: ClientTimeline
    let formatters: Formatters
    let now: Date
    let loadThumbnail: (Photo) async -> Data?
    let onOpenVisit: (VisitSummary) -> Void
    let onCompare: (Photo, Photo) -> Void

    @State private var kind: PhotoKind?
    @State private var isComparing = false
    @State private var picked: [Photo] = []
    @Environment(\.locale) private var locale

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: Spacing.sm)]

    var body: some View {
        let groups = PhotoGroup.groups(from: timeline, kind: kind)
        VStack(alignment: .leading, spacing: Spacing.md) {
            if timeline.visits.allSatisfy({ $0.photos.isEmpty }) && timeline.unlinkedPhotos.isEmpty {
                EmptyState(icon: .camera, title: "clientRecord.photos.empty.title",
                           message: "clientRecord.photos.empty.message")
                    .accessibilityIdentifier("clientRecord.photos.empty")
            } else {
                filters
                compareBar
                if groups.isEmpty {
                    Text("clientRecord.photos.noneOfKind")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                }
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(groups) { group in groupView(group) }
                }
            }
        }
        .accessibilityIdentifier("clientRecord.photos")
    }

    // MARK: - Sections

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterChip(nil, title: Text("clientRecord.photos.filter.all"))
                ForEach(PhotoKind.allCases, id: \.self) { kind in
                    filterChip(kind, title: Text(kind.title))
                }
            }
        }
        .accessibilityIdentifier("clientRecord.photos.filters")
    }

    private func filterChip(_ value: PhotoKind?, title: Text) -> some View {
        Button { kind = value } label: { title }
            .buttonStyle(.belloChip(selected: kind == value))
            .accessibilityAddTraits(kind == value ? .isSelected : [])
            .accessibilityIdentifier("clientRecord.photos.filter.\(value?.rawValue ?? "all")")
    }

    @ViewBuilder
    private var compareBar: some View {
        HStack(spacing: Spacing.sm) {
            if isComparing {
                Text(LocalizedStringResource(
                    "clientRecord.photos.pickTwo", defaultValue: "Pick two photos (\(picked.count) of 2)"
                ).localized(in: locale))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                Spacer(minLength: Spacing.sm)
                Button { stopComparing() } label: { Text("common.cancel") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("clientRecord.photos.compareCancel")
            } else {
                Spacer(minLength: 0)
                Button { isComparing = true } label: {
                    Label { Text("clientRecord.photos.compare") } icon: { Image(icon: .compare) }
                }
                .buttonStyle(.belloChip(selected: false))
                .accessibilityIdentifier("clientRecord.photos.compare")
            }
        }
    }

    private func groupView(_ group: PhotoGroup) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            groupHeader(group)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                ForEach(group.photos) { photo in tile(photo, in: group) }
            }
        }
    }

    @ViewBuilder
    private func groupHeader(_ group: PhotoGroup) -> some View {
        if let visit = group.visit {
            Button { onOpenVisit(visit) } label: {
                HStack(spacing: Spacing.xs) {
                    Text(verbatim: groupTitle(visit))
                        .font(Typography.metaStrong)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Image(icon: .forward).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink2)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Spacing.touchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("clientRecord.visit.openHint"))
        } else {
            Text("clientRecord.photos.unlinked")
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.ink)
                .frame(minHeight: Spacing.touchTarget)
        }
    }

    private func tile(_ photo: Photo, in group: PhotoGroup) -> some View {
        let isPicked = picked.contains(photo)
        return Button { tap(photo, in: group) } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { RecordThumbnail(photo: photo, size: nil, load: loadThumbnail) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(photo.kind.title)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Palette.surface, in: Capsule())
                        .padding(Spacing.xs)
                }
                .overlay {
                    if isPicked {
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(Palette.selectionInk, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringResource(
            "clientRecord.photos.tileLabel",
            defaultValue: "\(photo.kind.title.resolved(in: locale)), \(formatters.shortDate(photo.takenAt))"
        ).localized(in: locale)))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityIdentifier("clientRecord.photos.photo.\(photo.id.uuidString)")
    }

    private func groupTitle(_ visit: VisitSummary) -> String {
        let day = VisitDateLabel.text(visit.visitDate, formatters: formatters, now: now, locale: locale)
        return "\(day) · \(visit.record.serviceName)"
    }

    // MARK: - Actions

    private func tap(_ photo: Photo, in group: PhotoGroup) {
        guard isComparing else {
            if let visit = group.visit { onOpenVisit(visit) }
            return
        }
        if let index = picked.firstIndex(of: photo) {
            picked.remove(at: index)
            return
        }
        picked.append(photo)
        if picked.count == 2 {
            // Oldest on the leading side, so the comparison always reads from earlier to later.
            let pair = picked.sorted { $0.takenAt < $1.takenAt }
            onCompare(pair[0], pair[1])
            stopComparing()
        }
    }

    private func stopComparing() {
        isComparing = false
        picked = []
    }
}
