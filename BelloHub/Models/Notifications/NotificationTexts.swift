//
//  NotificationTexts.swift
//  BelloHub
//

import Foundation

/// The words of the local notifications, in the language of the app. **Generic on purpose**: the only values a text can
/// carry are counts, so no client name and no service name can reach a lock screen, however the planner is called
/// (docs/06-PRIVACY-SECURITY.md section 8; a test proves it for all fourteen localizations).
struct NotificationTexts: Sendable {
    let nextVisitTitle: String
    let nextVisitBody: String
    let birthdayTitle: String
    let birthdayBody: String
    let dailySummaryTitle: String
    /// "You have 3 visits today": the count of visits is the only value.
    let dailySummaryBody: @Sendable (Int) -> String
    let remindersReadyTitle: String
    /// "3 reminders are ready to send".
    let remindersReadyBody: @Sendable (Int) -> String

    static func localized(in locale: Locale) -> NotificationTexts {
        NotificationTexts(
            nextVisitTitle: LocalizedStringResource(
                "notification.nextVisit.title", defaultValue: "Your next visit is about to start"
            ).resolved(in: locale),
            nextVisitBody: LocalizedStringResource(
                "notification.nextVisit.body", defaultValue: "Open Bello Hub to see what to prepare."
            ).resolved(in: locale),
            birthdayTitle: LocalizedStringResource(
                "notification.birthday.title", defaultValue: "Birthdays tomorrow"
            ).resolved(in: locale),
            birthdayBody: LocalizedStringResource(
                "notification.birthday.body", defaultValue: "Open Bello Hub to see who, and send your wishes."
            ).resolved(in: locale),
            dailySummaryTitle: LocalizedStringResource(
                "notification.dailySummary.title", defaultValue: "Your day"
            ).resolved(in: locale),
            dailySummaryBody: { count in
                LocalizedStringResource(
                    "notification.dailySummary.body", defaultValue: "You have \(count) visits today."
                ).resolved(in: locale)
            },
            remindersReadyTitle: LocalizedStringResource(
                "notification.remindersReady.title", defaultValue: "Reminders ready"
            ).resolved(in: locale),
            remindersReadyBody: { count in
                LocalizedStringResource(
                    "notification.remindersReady.body", defaultValue: "\(count) reminders are ready to send."
                ).resolved(in: locale)
            }
        )
    }
}
