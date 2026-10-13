//
//  BookingReadinessSection.swift
//  BelloHub
//

import SwiftUI

/// Shows the professional whether her booking page has all 3 required elements to go online:
/// 1. Her link address (slug)
/// 2. Her store/workplace location address
/// 3. At least one active service
/// Only displayed when her page is not yet online, giving her a clear checklist of what is missing.
struct BookingReadinessSection: View {
    let viewModel: BookingSettingsViewModel
    let publishing: PublishingService
    let onOpenShareLink: () -> Void
    let onOpenWorkplace: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        if !publishing.state.isLive {
            SettingsSection(title: "bookingSettings.requirements.title") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ListCard(dividerInset: 56) {
                        linkRow
                        workplaceRow
                        servicesRow
                    }
                    guidanceNotice
                }
            }
            .accessibilityIdentifier("bookingSettings.requirementsSection")
        }
    }

    private var linkRow: some View {
        Button(action: onOpenShareLink) {
            HStack(spacing: Spacing.row) {
                Image(icon: viewModel.hasConfiguredLink ? .check : .link)
                    .foregroundStyle(viewModel.hasConfiguredLink ? Palette.sageText : Palette.roseText)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("bookingSettings.requirements.link")
                        .font(Typography.bodyStrong)
                        .foregroundStyle(Palette.ink)
                    if let link = viewModel.link {
                        Text(verbatim: link.display)
                            .font(Typography.meta)
                            .foregroundStyle(Palette.ink2)
                    } else {
                        Text("bookingSettings.requirements.linkMissing")
                            .font(Typography.meta)
                            .foregroundStyle(Palette.roseText)
                    }
                }
                Spacer()
                Image(icon: .forward)
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bookingSettings.requirements.linkRow")
    }

    private var workplaceRow: some View {
        Button(action: onOpenWorkplace) {
            HStack(spacing: Spacing.row) {
                Image(icon: viewModel.hasCompleteWorkplace ? .check : .mapPin)
                    .foregroundStyle(viewModel.hasCompleteWorkplace ? Palette.sageText : Palette.roseText)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("bookingSettings.requirements.workplace")
                        .font(Typography.bodyStrong)
                        .foregroundStyle(Palette.ink)
                    if let summary = viewModel.locationSummary {
                        Text(verbatim: summary)
                            .font(Typography.meta)
                            .foregroundStyle(Palette.ink2)
                    } else {
                        Text("bookingSettings.requirements.workplaceMissing")
                            .font(Typography.meta)
                            .foregroundStyle(Palette.roseText)
                    }
                }
                Spacer()
                Image(icon: .forward)
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bookingSettings.requirements.workplaceRow")
    }

    private var servicesRow: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: viewModel.hasActiveServices ? .check : .scissors)
                .foregroundStyle(viewModel.hasActiveServices ? Palette.sageText : Palette.roseText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("bookingSettings.requirements.services")
                    .font(Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                if viewModel.hasActiveServices {
                    Text(servicesActiveText)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                } else {
                    Text("bookingSettings.requirements.servicesMissing")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.roseText)
                }
            }
            Spacer()
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityIdentifier("bookingSettings.requirements.servicesRow")
    }

    private var servicesActiveText: LocalizedStringKey {
        "bookingSettings.requirements.servicesActive"
    }

    @ViewBuilder
    private var guidanceNotice: some View {
        if !viewModel.isReadyToGoOnline {
            InlineNotice(
                style: .warning,
                title: "bookingSettings.requirements.pendingTitle",
                message: "bookingSettings.requirements.pendingMessage"
            )
            .accessibilityIdentifier("bookingSettings.requirements.pendingNotice")
        } else {
            InlineNotice(
                style: .info,
                title: "bookingSettings.requirements.readyTitle",
                message: "bookingSettings.requirements.readyMessage"
            )
            .accessibilityIdentifier("bookingSettings.requirements.readyNotice")
        }
    }
}
