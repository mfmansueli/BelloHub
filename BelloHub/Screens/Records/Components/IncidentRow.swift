//
//  IncidentRow.swift
//  BelloHub
//

import SwiftUI

/// One reaction note in the record history: when, how serious, what was seen and done. Locked incidents are read only.
struct IncidentRow: View {
    let incident: Incident
    let formatters: Formatters

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
                Text(verbatim: formatters.dateTime(incident.occurredAt))
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
                Spacer(minLength: Spacing.sm)
                severity
            }
            if let symptoms = incident.symptoms {
                Text(verbatim: symptoms).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            }
            if let detail { Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2) }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recordHistory.incident.\(incident.id.uuidString)")
    }

    private var detail: String? {
        let parts = [incident.area, incident.actionTaken].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var severity: some View {
        switch incident.severity {
        case .mild: chip(.mild, style: StatusPalette.completed)
        case .moderate: chip(.moderate, style: StatusPalette.pending)
        case .severe: chip(.severe, style: StatusPalette.attention)
        }
    }

    private func chip(_ severity: IncidentSeverity, style: StatusStyle) -> some View {
        HStack(spacing: Spacing.xs + Spacing.xxs) {
            Circle().fill(style.dot).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(severity.title).font(Typography.caption).foregroundStyle(style.foreground)
        }
        .padding(.horizontal, Spacing.row)
        .frame(minHeight: 26)
        .background(style.background, in: Capsule())
    }
}
