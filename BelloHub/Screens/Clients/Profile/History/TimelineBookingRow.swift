//
//  TimelineBookingRow.swift
//  BelloHub
//

import SwiftUI

/// A booking on the timeline that is not a recorded visit. A completed one with no record says "Record pending" and
/// offers to fill it in (never required). A cancelled booking or a no-show is a quiet line, so it never looks like a
/// treatment that happened.
struct TimelineBookingRow: View {
    let appointment: Appointment
    let formatters: Formatters
    let now: Date
    /// Present for a completed booking with no record: opens the visit flow for it.
    var onRecord: (() -> Void)?
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.row) {
            Image(icon: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: "\(formatters.recentDate(appointment.startsAt, now: now)) · \(appointment.serviceName)")
                    .font(Typography.meta)
                    .foregroundStyle(ink)
                Text(statusText)
                    .font(Typography.metaStrong)
                    .foregroundStyle(ink)
            }
            Spacer(minLength: Spacing.sm)
            if let onRecord {
                Button(action: onRecord) { Text("clientRecord.pending.fill") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("clientRecord.pending.fill.\(appointment.id.uuidString)")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("clientRecord.booking.\(appointment.id.uuidString)")
    }

    private var statusText: LocalizedStringKey {
        switch appointment.status {
        case .completed: "clientRecord.pending.title"
        case .noShow: "clientRecord.notHeld.noShow"
        default: "clientRecord.notHeld.cancelled"
        }
    }

    private var icon: Icon {
        appointment.status == .completed ? .compose : .close
    }

    private var iconColor: Color { ink }

    /// The text color that belongs to the row's wash (pairs measured in the status palette).
    private var ink: Color {
        appointment.status == .completed ? Palette.amberText : Palette.neutralText
    }

    private var background: Color {
        appointment.status == .completed ? Palette.amberBg : Palette.neutralWash
    }
}
