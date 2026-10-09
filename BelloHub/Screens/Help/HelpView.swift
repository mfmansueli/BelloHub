//
//  HelpView.swift
//  BelloHub
//

import SwiftUI

/// 7.10 Help and support: common questions as rows that open their answer, then the ways to reach a person (e-mail
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
                    // Not a DisclosureGroup: outside a List only its small chevron toggles it, and a question she
                    // taps on the text does nothing. The whole row is the button; the answer sits under it.
                    let isOpen = expanded.contains(topic.id)
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation(Motion.ease(Motion.Duration.fade)) {
                                if isOpen { expanded.remove(topic.id) } else { expanded.insert(topic.id) }
                            }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                                Text(LocalizedStringKey(topic.questionKey))
                                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(icon: .forward)
                                    .font(Typography.meta.weight(.semibold)).foregroundStyle(Palette.ink3)
                                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: Spacing.touchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOpen ? [.isSelected] : [])
                        .accessibilityIdentifier("help.topic.\(topic.id)")
                        if isOpen {
                            Text(LocalizedStringKey(topic.answerKey))
                                .font(Typography.body).foregroundStyle(Palette.ink2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, Spacing.sm)
                                .accessibilityIdentifier("help.answer.\(topic.id)")
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
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
