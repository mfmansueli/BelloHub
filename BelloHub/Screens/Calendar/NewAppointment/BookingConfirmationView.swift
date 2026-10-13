//
//  BookingConfirmationView.swift
//  BelloHub
//

import SwiftUI

/// The confirmation screen shown after a professional books a visit from New appointment (3.1). It shows the details of
/// what was booked (client, service, day, time, duration, add-ons and guests) and a ready-to-send message the
/// professional can open in WhatsApp or Messages with one tap. She always reads it before it leaves (D14).
struct BookingConfirmationView: View {
    let client: Client
    let service: Service
    let visitType: VisitType
    let addOns: [AddOn]
    let guestNames: [String]
    let startsAt: Date
    let endsAt: Date
    let totalMinutes: Int
    let location: BusinessLocation?
    let messageText: String
    let formatters: Formatters

    let onSendWhatsApp: () -> Void
    let onSendSMS: () -> Void
    let onDone: () -> Void

    /// How the last send ended; nil before she taps.
    var outcome: MessageService.Outcome?

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                SuccessSeal(size: 72).padding(.top, Spacing.lg)
                Text(LocalizedStringResource("newAppointment.booked.title", defaultValue: "Appointment booked!"))
                    .font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("newAppointment.booked.title")
                summaryCard
                messageSection
                outcomeView
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Client
            HStack(spacing: Spacing.row) {
                Avatar(name: client.name, id: client.id.uuidString, size: 44)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: client.name)
                        .font(Typography.subtitle).foregroundStyle(Palette.ink)
                    Text(verbatim: service.name)
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("newAppointment.booked.client")

            Divider().overlay(Palette.hairline)

            // Date / time / duration
            VStack(alignment: .leading, spacing: Spacing.xs) {
                detailRow(
                    icon: .calendar,
                    text: formatters.weekdayDayMonth(startsAt)
                )
                let timeRange = "\(formatters.time(startsAt)) – \(formatters.time(endsAt))"
                let duration = formatters.duration(minutes: totalMinutes)
                detailRow(
                    icon: .clock,
                    text: "\(timeRange) · \(duration)"
                )
            }
            .padding(Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("newAppointment.booked.schedule")

            // Add-ons
            if !addOns.isEmpty {
                Divider().overlay(Palette.hairline)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(addOns, id: \.id) { addOn in
                        HStack(spacing: Spacing.sm) {
                            Text("+ \(addOn.name)")
                                .font(Typography.body).foregroundStyle(Palette.ink)
                            Spacer(minLength: Spacing.sm)
                            Text(verbatim: formatters.minutes(addOn.minutes))
                                .font(Typography.meta).foregroundStyle(Palette.ink2)
                        }
                    }
                }
                .padding(Spacing.md)
                .accessibilityIdentifier("newAppointment.booked.addOns")
            }

            // Guests
            if !guestNames.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).isEmpty {
                Divider().overlay(Palette.hairline)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("newAppointment.section.guests")
                        .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    Text(
                        verbatim: guestNames.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            .joined(separator: ", ")
                    )
                    .font(Typography.body).foregroundStyle(Palette.ink)
                }
                .padding(Spacing.md)
                .accessibilityIdentifier("newAppointment.booked.guests")
            }

            // Location
            if let location, BusinessLocationFormat.isComplete(location) {
                Divider().overlay(Palette.hairline)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(BusinessLocationFormat.lines(location), id: \.self) { line in
                        Text(verbatim: line)
                            .font(Typography.body).foregroundStyle(Palette.ink)
                    }
                    let directions = BusinessLocationFormat.clean(location.directions)
                    if !directions.isEmpty {
                        Text(verbatim: directions)
                            .font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                }
                .padding(Spacing.md)
                .accessibilityIdentifier("newAppointment.booked.location")
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.hairline)
        }
    }

    private func detailRow(icon: Icon, text: String) -> some View {
        HStack(spacing: Spacing.row) {
            Image(icon: icon).foregroundStyle(Palette.ink2).frame(width: 20)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(Typography.body).foregroundStyle(Palette.ink)
        }
    }

    // MARK: - Message

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "messageClient.preview")
            Text(verbatim: messageText)
                .font(Typography.body).foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.hairline)
                }
                .accessibilityIdentifier("newAppointment.booked.messagePreview")
            VStack(spacing: Spacing.sm) {
                if client.phoneE164 != nil {
                    HStack(spacing: Spacing.sm) {
                        Button(action: onSendWhatsApp) {
                            Label {
                                Text(
                                    LocalizedStringResource("newAppointment.booked.whatsApp", defaultValue: "WhatsApp")
                                )
                            } icon: {
                                Image(icon: .share)
                            }
                        }
                        .buttonStyle(.belloSecondary)
                        .accessibilityIdentifier("newAppointment.booked.whatsAppButton")

                        Button(action: onSendSMS) {
                            Label {
                                Text(
                                    LocalizedStringResource("newAppointment.booked.sms", defaultValue: "iMessage / SMS")
                                )
                            } icon: {
                                Image(icon: .share)
                            }
                        }
                        .buttonStyle(.belloSecondary)
                        .accessibilityIdentifier("newAppointment.booked.smsButton")
                    }
                }
                ShareLink(item: messageText) {
                    Label {
                        Text("appointment.share.button")
                    } icon: {
                        Image(icon: .share)
                    }
                }
                .buttonStyle(client.phoneE164 != nil ? .belloTertiary : .belloSecondary)
                .accessibilityIdentifier("newAppointment.booked.shareButton")
            }
        }
    }

    // MARK: - Outcome

    @ViewBuilder
    private var outcomeView: some View {
        switch outcome {
        case .opened(let channel)?:
            HStack(spacing: Spacing.sm) {
                InlineCheck()
                Text(channel == .whatsapp ? "appointment.opened.whatsapp" : "appointment.opened.sms")
                    .font(Typography.meta).foregroundStyle(Palette.sageText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("newAppointment.booked.opened")
        case .needsShareSheet(let text)?:
            ShareFallbackCard(text: text, identifier: "newAppointment.booked.shareFallback")
        case nil:
            EmptyView()
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        Button(action: onDone) {
            Text("common.done")
        }
        .buttonStyle(.belloPrimary)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("newAppointment.booked.doneButton")
    }
}
