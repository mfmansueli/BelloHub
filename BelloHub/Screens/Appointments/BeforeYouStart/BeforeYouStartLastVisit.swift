//
//  BeforeYouStartLastVisit.swift
//  BelloHub
//

import SwiftUI

/// The client's last visit, as "Before you start" needs it: the note she left for today, the visit card with its
/// photos, and what she wrote about technique, products, result and reaction. Only written values appear; a field she
/// left empty is not shown, and nothing is guessed from other visits.
struct BeforeYouStartLastVisit: View {
    let visit: VisitSummary
    let rememberToday: String?
    let formatters: Formatters
    let now: Date
    let loadThumbnail: (Photo) async -> Data?
    let onOpen: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let rememberToday { remember(rememberToday) }
            Text("beforeYouStart.lastVisit")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            VisitTimelineCard(visit: visit, formatters: formatters, now: now, loadThumbnail: loadThumbnail,
                              onOpen: onOpen)
            if !details.isEmpty { detailList }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("beforeYouStart.lastVisit")
    }

    // MARK: - Sections

    private func remember(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label { Text("beforeYouStart.rememberToday") } icon: { Image(icon: .history) }
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.roseText)
            Text(verbatim: text).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("beforeYouStart.rememberToday")
    }

    private var detailList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(details, id: \.label) { detail in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: detail.label).font(Typography.footnoteStrong).foregroundStyle(Palette.ink2)
                    Text(verbatim: detail.value).font(Typography.body).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard(cornerRadius: Radius.tile)
        .accessibilityIdentifier("beforeYouStart.lastVisit.details")
    }

    // MARK: - Content

    /// What was written, in the order she reads it before starting. The record already carries its corrections.
    private var details: [(label: String, value: String)] {
        let record = visit.record
        var rows: [(label: String, value: String)] = []
        func add(_ field: RecordCorrectableField, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            rows.append((field.title.resolved(in: locale), value))
        }
        add(.technique, record.technique)
        add(.productsUsed, record.productsUsed.isEmpty ? nil : formatters.list(record.productsUsed))
        let result = record.result.title.resolved(in: locale)
        let resultText = [result, record.resultDetail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        rows.append((LocalizedStringResource("beforeYouStart.result").resolved(in: locale), resultText))
        add(.reaction, record.reaction)
        return rows
    }
}
