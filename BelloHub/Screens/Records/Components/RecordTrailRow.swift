//
//  RecordTrailRow.swift
//  BelloHub
//

import SwiftUI

/// One line of the edit trail, on the timeline: a dot, the time, what happened and the detail.
struct RecordTrailRow: View {
    let entry: RecordTrailEntry
    let formatters: Formatters
    let professionalName: String
    var isLast = false
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dot.fill)
                    .overlay { Circle().strokeBorder(dot.stroke, lineWidth: 2) }
                    .frame(width: 16, height: 16)
                if !isLast {
                    Rectangle().fill(Palette.hairline).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: formatters.dateTime(entry.date)).font(Typography.footnote).foregroundStyle(Palette.ink2)
                title.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                if let detail { Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2) }
            }
            .padding(.bottom, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recordHistory.trail.\(entry.id)")
    }

    // MARK: - Content

    private var dot: (fill: Color, stroke: Color) {
        switch entry.kind {
        case .created: (Palette.surface, Palette.ink2)
        case .finalized: (Palette.surface, Palette.sage)
        case .locked: (Palette.sageWash, Palette.sage)
        case .correction: (Palette.roseWash, Palette.rose)
        }
    }

    private var title: Text {
        switch entry.kind {
        case .created:
            Text(LocalizedStringResource(
                "recordHistory.trail.created", defaultValue: "Created by \(professionalName)"
            ).localized(in: locale))
        case .finalized: Text("recordHistory.trail.finalized")
        case .locked: Text("recordHistory.trail.locked")
        case .correction:
            Text(LocalizedStringResource(
                "recordHistory.trail.correction", defaultValue: "Correction by \(professionalName)"
            ).localized(in: locale))
        }
    }

    private var detail: String? {
        switch entry.kind {
        case .created(let source, let result, let products):
            createdDetail(source: source, result: result, products: products)
        case .finalized:
            LocalizedStringResource("recordHistory.trail.finalizedDetail").resolved(in: locale)
        case .locked:
            LocalizedStringResource("recordHistory.trail.lockedDetail").resolved(in: locale)
        case .correction(let correction, let entryName):
            correctionDetail(correction, entryName: entryName)
        }
    }

    private func createdDetail(source: RecordSource, result: RecordResult, products: [String]) -> String {
        var parts = [source == .voice
            ? LocalizedStringResource("recordHistory.trail.fromVoice").resolved(in: locale)
            : LocalizedStringResource("recordHistory.trail.fromManual").resolved(in: locale)]
        if !products.isEmpty {
            let list = formatters.list(products)
            parts.append(LocalizedStringResource(
                "recordHistory.trail.products", defaultValue: "Products: \(list)."
            ).resolved(in: locale))
        }
        let name = result.title.resolved(in: locale)
        parts.append(LocalizedStringResource(
            "recordHistory.trail.result", defaultValue: "Result: \(name)."
        ).resolved(in: locale))
        return parts.joined(separator: " ")
    }

    private func correctionDetail(_ correction: RecordCorrection, entryName: String?) -> String {
        let isVisitDay = correction.fieldKey == RecordCurrentValues.performedAtKey
        let field = isVisitDay
            ? LocalizedStringResource("record.field.visitDate").resolved(in: locale)
            : RecordCorrectableField(rawValue: correction.fieldKey)?.title.resolved(in: locale)
                ?? entryName ?? correction.fieldKey
        // A visit day is stored as an instant; it reads as a day.
        let readable: (String?) -> String? = { value in
            guard isVisitDay else { return value }
            return value.flatMap(RecordCurrentValues.date(from:)).map(formatters.shortDate) ?? value
        }
        let old = readable(correction.oldValue)
        let new = readable(correction.newValue)
        var parts: [String] = []
        switch (old, new) {
        case (.some(let old), .some(let new)):
            parts.append(LocalizedStringResource(
                "recordHistory.trail.changed", defaultValue: "\(field): \(old) became \(new)."
            ).resolved(in: locale))
        case (.none, .some(let new)):
            parts.append(LocalizedStringResource(
                "recordHistory.trail.added", defaultValue: "\(field) added: \(new)."
            ).resolved(in: locale))
        case (.some, .none):
            parts.append(LocalizedStringResource(
                "recordHistory.trail.cleared", defaultValue: "\(field) was cleared."
            ).resolved(in: locale))
        case (.none, .none):
            break
        }
        if let reason = correction.reason {
            parts.append(LocalizedStringResource(
                "recordHistory.trail.reason", defaultValue: "Reason: \(reason)"
            ).resolved(in: locale))
        }
        return parts.joined(separator: " ")
    }
}
