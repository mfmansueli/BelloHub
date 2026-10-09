//
//  PolicyRuleText.swift
//  BelloHub
//

import Foundation

/// The sentences a **client** reads about her cancellation, rescheduling and no-show rules, produced from the policy
/// values in any of the fourteen localizations (docs/07-LOCALIZATION.md section 7). The app shows them under "What
/// clients read" and publishes the very same strings per locale to the booking page, so the two can never disagree:
/// this type is the only owner of the wording.
///
/// The text is written for the client ("you") and says the professional's first name where the rule involves her, in
/// words that need no gender agreement. In Arabic the name is isolated so it cannot reorder the sentence.
struct PolicyRuleText: Sendable {
    let localization: AppLocalization
    /// The professional's first name, as the client knows her.
    let professionalName: String

    init(localization: AppLocalization, professionalName: String) {
        self.localization = localization
        self.professionalName = professionalName
    }

    // MARK: - The rules

    /// Every line, in reading order: how the personal link works, the free window and what follows it, rescheduling,
    /// late arrivals and, when protection is on, the no-show rule.
    func lines(cancellation: CancellationPolicy, noShow: NoShowPolicy) -> [String] {
        let freeLine = [freeWindow(cancellation.freeWindowHours), afterWindowCancel(cancellation, noShow: noShow)]
            .joined(separator: " ")
        var result = [personalLink, freeLine, rescheduling(cancellation), grace(cancellation.graceMinutes)]
        if let line = noShowLine(noShow) { result.append(line) }
        return result
    }

    /// The no-show rule alone, or nil when protection is off. The booking page shows it under the cancellation rules,
    /// and the No-show screen shows the same sentence.
    func noShowLine(_ policy: NoShowPolicy) -> String? {
        guard policy.isOn else { return nil }
        let limit = policy.limit
        switch policy.action {
        case .tell:
            return text(LocalizedStringResource(
                "policy.rule.noShowTell",
                defaultValue: "{professional} keeps track of appointments that are missed without a message."
            ))
        case .approveNewBookings:
            return text(LocalizedStringResource(
                "policy.rule.noShowApprove",
                defaultValue: """
                After \(limit) missed appointments without a message, \
                {professional} confirms your new bookings personally.
                """
            ))
        case .pauseOnline:
            return text(LocalizedStringResource(
                "policy.rule.noShowPause",
                defaultValue: """
                After \(limit) missed appointments without a message, \
                online booking pauses and {professional} contacts you.
                """
            ))
        }
    }

    // MARK: - The paused page

    /// What a client sees on a page that is not taking bookings: the title and, with a return date, when it opens
    /// again. `until` is shown in the business time zone, as every date a client reads.
    func pausedNotice(until: Date?, timeZone: TimeZone) -> [String] {
        let title = text(LocalizedStringResource(
            "policy.rule.pausedTitle", defaultValue: "{professional} is not accepting new bookings right now."
        ))
        guard let until else {
            return [title, text(LocalizedStringResource(
                "policy.rule.pausedNoDate",
                defaultValue: "Send a message and you will get a reply as soon as possible."
            ))]
        }
        let formatters = Formatters(locale: localization.locale, timeZone: timeZone, currencyCode: "EUR")
        let date = isolated(formatters.weekdayDayMonth(until))
        let back = text(LocalizedStringResource(
            "policy.rule.pausedBack", defaultValue: "Back on {date}. Send a message and you will get a reply."
        )).replacingOccurrences(of: "{date}", with: date)
        return [title, back]
    }

    // MARK: - Parts

    private var personalLink: String {
        text(LocalizedStringResource(
            "policy.rule.personalLink",
            defaultValue: """
            After you book, you get a personal link on the confirmation page, and by email if you share one. \
            Use it any time to cancel or reschedule. No app or password.
            """
        ))
    }

    private func freeWindow(_ hours: Int) -> String {
        text(LocalizedStringResource("policy.rule.free", defaultValue: "Free changes up to \(hours) hours before."))
    }

    private func afterWindowCancel(_ policy: CancellationPolicy, noShow: NoShowPolicy) -> String {
        switch policy.afterWindowCancel {
        case .allow:
            if noShow.isOn && noShow.lateCancelCounts {
                return text(LocalizedStringResource(
                    "policy.rule.cancelAllowedCounts",
                    defaultValue: """
                    After that you can still cancel here, and {professional} is told right away. \
                    It counts as a missed appointment.
                    """
                ))
            }
            return text(LocalizedStringResource(
                "policy.rule.cancelAllowed",
                defaultValue: "After that you can still cancel here, and {professional} is told right away."
            ))
        case .message:
            return text(LocalizedStringResource(
                "policy.rule.cancelMessage", defaultValue: "After that, please message {professional}."
            ))
        }
    }

    private func rescheduling(_ policy: CancellationPolicy) -> String {
        guard policy.clientCanReschedule else {
            return text(LocalizedStringResource(
                "policy.rule.rescheduleNo", defaultValue: "To reschedule, please message {professional}."
            ))
        }
        var parts: [String] = []
        if let maximum = policy.maxReschedules {
            parts.append(text(LocalizedStringResource(
                "policy.rule.rescheduleUpTo", defaultValue: "You can reschedule up to \(maximum) times."
            )))
        } else {
            parts.append(text(LocalizedStringResource(
                "policy.rule.rescheduleAny", defaultValue: "You can reschedule as often as you need."
            )))
        }
        switch policy.afterWindowReschedule {
        case .request:
            parts.append(text(LocalizedStringResource(
                "policy.rule.rescheduleRequest",
                defaultValue: "To reschedule after that, send {professional} a request."
            )))
        case .message:
            parts.append(text(LocalizedStringResource(
                "policy.rule.rescheduleMessage",
                defaultValue: "To reschedule after that, please message {professional}."
            )))
        }
        return parts.joined(separator: " ")
    }

    private func grace(_ minutes: Int) -> String {
        text(LocalizedStringResource(
            "policy.rule.grace",
            defaultValue: """
            {professional} holds your time for \(minutes) minutes if you are late. \
            Let them know from this page.
            """
        ))
    }

    /// Looks the sentence up in the localization and puts the professional's name in. The name is a placeholder in the
    /// catalog, not an argument, so the plural forms only ever depend on the number.
    private func text(_ resource: LocalizedStringResource) -> String {
        var localized = resource
        localized.locale = localization.locale
        return String(localized: localized).replacingOccurrences(of: "{professional}", with: isolated(professionalName))
    }

    /// Isolates a name or date in Arabic only: in the other languages the invisible marks would be noise in a copied
    /// sentence.
    private func isolated(_ value: String) -> String {
        localization.isRightToLeft ? BidiIsolate.wrap(value) : value
    }
}
