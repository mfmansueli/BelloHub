//
//  TeamView.swift
//  BelloHub
//

import SwiftUI

/// 6.11 Team: a static "later" screen (D5). Bello Hub is for one professional in this version, so nothing here can be
/// switched or saved: it says that teams are coming, and shows what she will be able to decide when they do, so the
/// row in More is not a dead end. No state, no ViewModel.
struct TeamView: View {
    private struct Plan: Identifiable {
        let id: String
        let icon: Icon
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
    }

    private static let plans = [
        Plan(id: "book", icon: .clients, title: "team.plan.book.title", subtitle: "team.plan.book.subtitle"),
        Plan(id: "history", icon: .document, title: "team.plan.history.title", subtitle: "team.plan.history.subtitle"),
        Plan(id: "photos", icon: .image, title: "team.plan.photos.title", subtitle: "team.plan.photos.subtitle"),
        Plan(id: "services", icon: .sliders, title: "team.plan.services.title", subtitle: "team.plan.services.subtitle")
    ]

    init() {}

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                Text("team.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                InlineNotice(style: .info, title: "team.later.title", message: "team.later.message")
                    .accessibilityIdentifier("team.later")
                plansSection
                FooterNote(text: "team.footer", icon: .info)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("team.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("team.section.plans")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.row)
            ListCard(dividerInset: 72) {
                ForEach(Self.plans) { plan in
                    HStack(spacing: Spacing.row) {
                        Image(icon: plan.icon)
                            .foregroundStyle(Palette.roseDeepText)
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                            .background(
                                Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            )
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(plan.title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                            Text(plan.subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(minHeight: 64)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("team.plan.\(plan.id)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { TeamView() }
}
