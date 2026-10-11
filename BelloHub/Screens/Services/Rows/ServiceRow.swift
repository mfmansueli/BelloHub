//
//  ServiceRow.swift
//  BelloHub
//

import SwiftUI

/// One service in the list: its name and price, its category and length, and a badge for each setting that is on
/// (follow-up, photos, aftercare, patch test, contraindications) and for a service that is switched off. One element
/// for VoiceOver, read in the order a person scans it.
struct ServiceRow: View {
    let service: Service
    let formatters: Formatters

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            titleLine
            Text(verbatim: details).font(Typography.meta).foregroundStyle(Palette.ink2)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                badges
            }
        }
        .padding(.vertical, Spacing.row)
        .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Parts

    /// At the accessibility sizes the price moves under the name instead of squeezing it.
    @ViewBuilder
    private var titleLine: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                name
                price
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                name
                Spacer(minLength: Spacing.sm)
                price
            }
        }
    }

    private var name: some View {
        Text(verbatim: service.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink).layoutPriority(1)
    }

    @ViewBuilder
    private var price: some View {
        if let text = priceText {
            text.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
        }
    }

    @ViewBuilder
    private var badges: some View {
        if !service.isActive {
            ServiceBadge(text: Text("services.badge.inactive"), style: .inactive)
        }
        if let weeks = service.followUpWeeks {
            ServiceBadge(text: Text(LocalizedStringResource(
                "services.badge.followUp", defaultValue: "Follow-up \(formatters.weeks(weeks))"
            ).localized(in: locale)))
        }
        if service.remindBeforeAfterPhotos { ServiceBadge(text: Text("services.badge.photos")) }
        if service.aftercareTemplate != nil { ServiceBadge(text: Text("services.badge.aftercare")) }
        if service.requiresPatchTest { ServiceBadge(text: Text("services.badge.patchTest")) }
        if !service.contraindications.isEmpty {
            ServiceBadge(
                text: Text(LocalizedStringResource(
                    "services.badge.contraindications",
                    defaultValue: "\(service.contraindications.count) contraindications"
                ).localized(in: locale)),
                style: .caution
            )
        }
    }

    // MARK: - Text

    /// "Facial · 60 min", or just the length when the service has no category.
    private var details: String {
        [service.category, formatters.minutes(service.durationMinutes)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var priceText: Text? {
        switch ServicePriceLine(service) {
        case .none:
            return nil
        case .exact(let amount):
            return Text(verbatim: formatters.money(amount))
        case .startingFrom(let amount):
            return Text(LocalizedStringResource(
                "services.price.from", defaultValue: "From \(formatters.money(amount))"
            ).localized(in: locale))
        case .onRequest:
            return Text("services.price.onRequest")
        case .hidden:
            return Text("services.price.hidden")
        }
    }
}
