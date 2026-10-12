//
//  AppointmentActionsSection.swift
//  BelloHub
//

import SwiftUI

/// The buttons of a visit's detail, laid out as `AppointmentActionRules` says: one main button, a row of tiles and the
/// text links under them. It decides nothing: it draws the layout it is given and reports the tap.
struct AppointmentActionsSection: View {
    let layout: AppointmentActionLayout
    let isWorking: Bool
    let onAction: (AppointmentAction) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let primary = layout.primary {
                Button { onAction(primary) } label: {
                    Label { Text(title(of: primary)) } icon: { Image(icon: icon(of: primary)) }
                }
                .buttonStyle(.belloPrimary)
                .disabled(isWorking)
                .accessibilityIdentifier("appointment.\(primary.rawValue)Button")
            }
            if !layout.quick.isEmpty { quickTiles }
            if !layout.secondary.isEmpty { secondaryLinks }
        }
    }

    private var quickTiles: some View {
        FittingRow(fillsWidth: true) {
            ForEach(layout.quick, id: \.self) { action in
                Button { onAction(action) } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(icon: icon(of: action)).font(.system(size: 18, weight: .medium))
                        Text(title(of: action)).font(Typography.metaStrong).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .padding(.vertical, Spacing.sm)
                    .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                }
                .disabled(isWorking)
                .accessibilityIdentifier("appointment.\(action.rawValue)Button")
            }
        }
    }

    private var secondaryLinks: some View {
        FlowLayout(spacing: Spacing.md, lineSpacing: Spacing.xs, wrapsLongChildren: true) {
            ForEach(layout.secondary, id: \.self) { action in
                Button { onAction(action) } label: {
                    Text(title(of: action))
                        .font(Typography.calloutStrong)
                        .foregroundStyle([.noShow, .cancel].contains(action) ? Palette.coralText : Palette.ink)
                        .frame(minHeight: Spacing.touchTarget)
                }
                .accessibilityIdentifier("appointment.\(action.rawValue)Button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(of action: AppointmentAction) -> LocalizedStringKey {
        switch action {
        case .beforeYouStart: "appointment.action.beforeYouStart"
        case .complete: "appointment.action.complete"
        case .message: "appointment.action.message"
        case .runningLate: "appointment.action.runningLate"
        case .reschedule: "appointment.action.reschedule"
        case .noShow: "appointment.action.noShow"
        case .cancel: "appointment.action.cancel"
        case .registerVisit: "clientRecord.register"
        case .continueRecord: "visitDetail.draft.continue"
        case .openRecord: "visitForm.saved.open"
        }
    }

    private func icon(of action: AppointmentAction) -> Icon {
        switch action {
        case .beforeYouStart: .sparkle
        case .complete: .check
        case .message: .chat
        case .runningLate: .clock
        case .reschedule: .calendar
        case .noShow: .alert
        case .cancel: .close
        case .registerVisit, .continueRecord: .compose
        case .openRecord: .document
        }
    }
}
