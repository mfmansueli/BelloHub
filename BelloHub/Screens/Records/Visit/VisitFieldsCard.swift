//
//  VisitFieldsCard.swift
//  BelloHub
//

import SwiftUI

/// Every field the visit's record has, as it reads now (corrections applied), in three groups: what was done, the
/// result and the reaction, and the aftercare and what comes next. Only what she wrote is shown; an empty field is
/// left out, and an empty record says so.
struct VisitFieldsCard: View {
    let values: RecordCurrentValues
    let entries: [RecordFieldEntry]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            group("visitDetail.group.done", rows: doneRows)
            resultGroup
            group("visitDetail.group.next", rows: nextRows)
            if doneRows.isEmpty, nextRows.isEmpty, resultRows.isEmpty {
                Text("visitDetail.fields.empty")
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("visitDetail.fields")
    }

    // MARK: - Rows

    private struct Row: Identifiable {
        let id: String
        let label: String
        let value: String
        var isPrivate = false
    }

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: .current, currencyCode: "USD")
    }

    private func standard(_ field: RecordCorrectableField, isPrivate: Bool = false) -> Row? {
        guard let value = values.value(field), !value.isEmpty else { return nil }
        return Row(id: field.rawValue, label: field.title.resolved(in: locale), value: value, isPrivate: isPrivate)
    }

    private var doneRows: [Row] {
        var rows = [standard(.technique)].compactMap { $0 }
        let products = values.products
        if !products.isEmpty {
            rows.append(Row(id: "products", label: RecordCorrectableField.productsUsed.title.resolved(in: locale),
                            value: formatters.list(products)))
        }
        rows += entries.map { entry in
            Row(id: "field.\(entry.key)", label: entry.name,
                value: RecordEntryText.text(entry, formatters: formatters, locale: locale))
        }
        if let notes = standard(.notes, isPrivate: true) { rows.append(notes) }
        return rows
    }

    private var resultRows: [Row] {
        [standard(.resultDetail), standard(.reaction)].compactMap { $0 }
    }

    private var nextRows: [Row] {
        [standard(.aftercare), standard(.nextSessionSuggestion), standard(.nextVisitReminder, isPrivate: true)]
            .compactMap { $0 }
    }

    // MARK: - Groups

    @ViewBuilder
    private func group(_ title: LocalizedStringKey, rows: [Row]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                groupTitle(title)
                ForEach(rows) { row in rowView(row) }
            }
        }
    }

    private var resultGroup: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            groupTitle("visitDetail.group.result")
            StatusChip(label: resultKey, style: values.record.result == .reaction
                ? StatusPalette.attention : StatusPalette.completed)
                .accessibilityIdentifier("visitDetail.result")
            ForEach(resultRows) { row in rowView(row) }
        }
    }

    private var resultKey: LocalizedStringKey {
        switch values.record.result {
        case .great: "treatmentFlow.result.great"
        case .good: "treatmentFlow.result.good"
        case .neutral: "treatmentFlow.result.neutral"
        case .reaction: "treatmentFlow.result.reaction"
        }
    }

    private func groupTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Typography.section)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func rowView(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(verbatim: row.label)
                    .font(Typography.footnoteStrong)
                    .foregroundStyle(Palette.ink2)
                if row.isPrivate {
                    Image(icon: .lock)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .accessibilityLabel(Text("visitDetail.privateField"))
                }
            }
            Text(verbatim: row.value)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visitDetail.field.\(row.id)")
    }
}
