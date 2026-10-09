//
//  ConsentRecordRow.swift
//  BelloHub
//

import SwiftUI

/// One consent record: her label (or the kind's title), signed or not as a chip with a word (never color alone),
/// the date, and whether a note or a document is kept with it. Tapping it opens the record. One element for
/// VoiceOver, with a hint that says what the tap does. At accessibility sizes the chip drops under the text.
struct ConsentRecordRow: View {
    let record: ConsentRecord
    let formatters: Formatters
    let identifier: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        summary
                        chip
                    }
                } else {
                    summary
                    Spacer(minLength: Spacing.sm)
                    chip
                }
                Image(icon: .forward)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("health.consent.openHint"))
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Parts

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: record.displayLabel(kindTitle: text(record.kind.title)))
                .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2)
            if !extras.isEmpty {
                Text(verbatim: extras).font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    @ViewBuilder
    private var chip: some View {
        if record.isSigned {
            StatusChip(label: "health.consent.status.signed", style: StatusPalette.confirmed)
        } else {
            StatusChip(label: "health.consent.status.notSigned", style: StatusPalette.pending)
        }
    }

    /// "Signed · Sep 12" or "Not signed · noted Sep 12".
    private var detail: String {
        let date = BidiIsolate.wrap(formatters.shortDate(record.effectiveDate))
        let resource: LocalizedStringResource = record.isSigned
            ? LocalizedStringResource("health.consent.signedOn", defaultValue: "Signed · \(date)")
            : LocalizedStringResource("health.consent.notedOn", defaultValue: "Not signed · noted \(date)")
        return text(resource)
    }

    /// "Photo kept · Note", what travels with the record.
    private var extras: String {
        var parts: [String] = []
        switch record.document?.kind {
        case .photo?: parts.append(text("health.consent.hasPhoto"))
        case .file?: parts.append(text("health.consent.hasFile"))
        case nil: break
        }
        if let note = record.note, !note.isEmpty { parts.append(text("health.consent.hasNote")) }
        return formatters.list(parts)
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }
}
