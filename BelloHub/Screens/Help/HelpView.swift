//
//  HelpView.swift
//  BelloHub
//

import SwiftUI

/// 7.10 Help and support: common questions as native disclosure groups, then the ways to reach a person (e-mail
/// support, send feedback). No chat in v1: the prototype's "Chat with support" has no service behind it, so the
/// row is e-mail (see the S10 notes). Presentation only: local state, no ViewModel.
struct HelpView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("help.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                questions
                contact
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("help.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var questions: some View {
        SettingsSection(title: "help.section.questions") {
            ListCard(dividerInset: Spacing.md) {
                ForEach(HelpTopics.topics) { topic in
                    DisclosureGroup(isExpanded: Binding(
                        get: { expanded.contains(topic.id) },
                        set: { open in if open { expanded.insert(topic.id) } else { expanded.remove(topic.id) } }
                    )) {
                        Text(LocalizedStringKey(topic.answerKey))
                            .font(Typography.body).foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.sm)
                            .accessibilityIdentifier("help.answer.\(topic.id)")
                    } label: {
                        Text(LocalizedStringKey(topic.questionKey))
                            .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(Palette.ink3)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .accessibilityIdentifier("help.topic.\(topic.id)")
                }
            }
        }
    }

    private var contact: some View {
        SettingsSection(title: "help.section.person") {
            ListCard(dividerInset: 72) {
                Button { mail(subject: String(localized: "help.mail.supportSubject")) } label: {
                    MoreRow(icon: .mail, tint: .rose, title: Text("help.contact"),
                            subtitle: Text(verbatim: HelpTopics.supportEmail), showsChevron: true)
                }
                .accessibilityIdentifier("help.contactButton")
                Button { mail(subject: String(localized: "help.mail.feedbackSubject")) } label: {
                    MoreRow(icon: .chat, tint: .sage, title: Text("help.feedback"),
                            subtitle: Text("help.feedback.subtitle"), showsChevron: true)
                }
                .accessibilityIdentifier("help.feedbackButton")
            }
        }
    }

    private func mail(subject: String) {
        guard let url = HelpTopics.mailURL(subject: subject) else { return }
        openURL(url)
    }
}

#Preview {
    NavigationStack { HelpView() }
}
