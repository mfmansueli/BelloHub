//
//  CatalogComponentsSection.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Cards, tiles, hero, empty state, notices, field, offline banner, skeleton.
struct CatalogComponentsSection: View {
    @State private var name = ""
    @State private var showsSheet = false
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogSection(title: "Components", identifier: "catalog.section.components") {
            hero
            SectionHeader(
                title: "catalog.sample.sectionTitle",
                actionTitle: LocalizedStringResource("catalog.sample.sectionAction", defaultValue: "\(2) left")
                    .localized(in: locale)
            ) {}
            ListCard {
                row("Julia Mendes", status: StatusPalette.completed, label: "catalog.sample.completed")
                row("Ana Costa", status: StatusPalette.confirmed, label: "catalog.sample.confirmed")
            }
            HStack(spacing: Spacing.sm) {
                InsightTile(icon: .calendar, value: "12", label: "catalog.sample.tile.visits", tone: .sage)
                InsightTile(icon: .clock, value: "3", label: "catalog.sample.tile.waitlist", tone: .rose)
                InsightTile(icon: .repeatArrows, value: "3", label: "catalog.sample.tile.winback", tone: .peach)
            }
            .fixedSize(horizontal: false, vertical: true)
            InlineNotice(style: .safety, title: "catalog.sample.noticeTitle", message: "catalog.sample.noticeMessage")
            InlineNotice(style: .info, title: "catalog.sample.infoTitle")
            InlineNotice(style: .warning, title: "catalog.sample.warningTitle")
            BelloTextField(title: "catalog.sample.fieldLabel", text: $name, prompt: "catalog.sample.fieldPrompt")
            BelloTextField(title: "catalog.sample.fieldLabel", text: .constant("A"),
                           errorMessage: "catalog.sample.fieldError")
            OfflineBanner(message: "catalog.sample.offline")
            EmptyState(icon: .calendar, title: "catalog.sample.emptyTitle", message: "catalog.sample.emptyMessage",
                       actionTitle: "catalog.sample.emptyAction") {}
            VStack(spacing: Spacing.sm) {
                Skeleton(height: 18)
                Skeleton(height: 18)
            }
            FooterNote(text: "catalog.sample.footer")
            Button { showsSheet = true } label: { Text("catalog.sample.sheetTitle") }
                .buttonStyle(.belloSecondary)
        }
        .sheet(isPresented: $showsSheet) {
            VStack(alignment: .leading) {
                SheetHeader(title: "catalog.sample.sheetTitle", closeLabel: "catalog.sample.closeLabel") {
                    showsSheet = false
                }
                Spacer()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var hero: some View {
        HeroCard(isAnimated: true) {
            VStack(alignment: .leading, spacing: Spacing.row) {
                HStack {
                    Text("catalog.sample.nextUp").font(Typography.meta).foregroundStyle(HeroPalette.ink2)
                    Spacer()
                    Text(verbatim: "11:30").font(Typography.moment).foregroundStyle(HeroPalette.ink)
                }
                HStack(spacing: Spacing.row) {
                    Avatar(name: "Camila Rocha", id: "camila", size: 56)
                    VStack(alignment: .leading) {
                        Text(verbatim: "Camila Rocha").font(Typography.section).foregroundStyle(HeroPalette.ink)
                        Text(verbatim: "Glow Facial · 60").font(Typography.meta).foregroundStyle(HeroPalette.ink2)
                    }
                }
                Button {} label: { Text("catalog.sample.primary") }.buttonStyle(.belloOnHero)
            }
        }
    }

    private func row(_ name: String, status: StatusStyle, label: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: name, id: name)
            Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.sm)
            StatusChip(label: label, style: status)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
#endif
