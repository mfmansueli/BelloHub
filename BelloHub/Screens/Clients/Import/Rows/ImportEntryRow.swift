//
//  ImportEntryRow.swift
//  BelloHub
//

import SwiftUI

/// One client she can bring over: an avatar, the name, the phone, and a round check she taps. The whole row is the
/// button and one VoiceOver element ("Ana Costa, +55 11 98765-4321, selected").
///
/// The check is drawn here and not with the list's edit-mode selection because the system draws a white check on the
/// tint, which on `ink` in dark appearance is cream-on-white (1.1:1); this one uses the token pair for both.
struct ImportEntryRow: View {
    let entry: ImportEntry
    let phoneText: String?
    let isSelected: Bool
    /// Her list already has this person (same phone): importing skips the row, so it says so.
    var isAlreadyInList = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                Avatar(name: entry.displayName, id: entry.id, size: 36)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: BidiIsolate.wrap(entry.displayName))
                        .font(Typography.calloutStrong)
                        .foregroundStyle(Palette.ink)
                    secondaryLine
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.sm)
                check
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("importClients.row.\(entry.id)")
    }

    @ViewBuilder
    private var secondaryLine: some View {
        if isAlreadyInList {
            Text("import.row.alreadyInList").font(Typography.footnoteStrong).foregroundStyle(Palette.ink2)
        }
        if let phoneText {
            Text(verbatim: phoneText).font(Typography.footnote).foregroundStyle(Palette.ink2)
        } else {
            Text("import.noPhone").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var check: some View {
        ZStack {
            Circle().fill(isSelected ? Palette.action : Color.clear)
            Circle().strokeBorder(isSelected ? Palette.action : Palette.fieldBorder, lineWidth: 1.5)
            if isSelected {
                Image(icon: .check)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.onAction)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
