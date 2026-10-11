//
//  FollowUpReasonText.swift
//  BelloHub
//

import Foundation

/// The plain sentence that says why a suggestion is in the queue and where its message stands (routine-a items 6 and
/// 12). Built only from facts she can check in her own visits and services; it never infers anything clinical and
/// never promises a result. One owner, so the queue, Home and Alerts say the same thing.
struct FollowUpReasonText {
    let formatters: Formatters

    func why(_ reason: FollowUpReason) -> String {
        switch reason {
        case let .reminder(start, _):
            let when = "\(formatters.weekdayDayMonth(start)), \(formatters.time(start))"
            return text(LocalizedStringResource(
                "followUpQueue.reason.reminder",
                defaultValue: "Visit on \(when). Reminders are ready from the evening before."
            ))
        case let .unfinishedVisit(service, steps):
            let open = formatters.list(steps.map(stepName))
            return text(LocalizedStringResource(
                "followUpQueue.reason.unfinished",
                defaultValue: "\(BidiIsolate.wrap(service)): you chose Finish later. Still open: \(open)."
            ))
        case let .postVisit(start, service):
            let day = formatters.weekdayDayMonth(start)
            return text(LocalizedStringResource(
                "followUpQueue.reason.postVisit",
                defaultValue: "\(BidiIsolate.wrap(service)) on \(day). A short check-in after the visit is optional."
            ))
        case let .returnDue(service, weeks, _):
            if let weeks {
                let interval = formatters.weeks(weeks)
                return text(LocalizedStringResource(
                    "followUpQueue.reason.returnDue",
                    defaultValue: """
                    The usual interval for \(BidiIsolate.wrap(service)) (\(interval)) has passed and no return is \
                    booked.
                    """
                ))
            }
            return text(LocalizedStringResource(
                "followUpQueue.reason.returnDueNoInterval",
                defaultValue: "The usual interval for \(BidiIsolate.wrap(service)) has passed and no return is booked."
            ))
        case let .notBack(days):
            let ago = formatters.daysAgo(days)
            return text(LocalizedStringResource(
                "followUpQueue.reason.notBack", defaultValue: "Last visit \(ago), and nothing is booked."
            ))
        case let .birthday(date, isToday):
            if isToday {
                return text(LocalizedStringResource(
                    "followUpQueue.reason.birthdayToday", defaultValue: "Birthday today."
                ))
            }
            let day = formatters.weekdayDayMonth(date)
            return text(LocalizedStringResource(
                "followUpQueue.reason.birthday", defaultValue: "Birthday on \(day)."
            ))
        }
    }

    /// Where the message stands. Opening WhatsApp proves neither sending nor delivery, so the opened state says so,
    /// and her own mark is always called hers.
    func delivery(_ state: MessageDeliveryState) -> String {
        switch state {
        case .readyToSend:
            return text(LocalizedStringResource("followUpQueue.delivery.ready", defaultValue: "Ready to send"))
        case .conversationOpened(let at):
            let when = moment(at)
            return text(LocalizedStringResource(
                "followUpQueue.delivery.opened",
                defaultValue: "Conversation opened \(when). Opening WhatsApp does not confirm the message was sent."
            ))
        case .markedSentByHer(let at):
            let when = moment(at)
            return text(LocalizedStringResource(
                "followUpQueue.delivery.marked", defaultValue: "Marked as sent by you, \(when)"
            ))
        }
    }

    func stepName(_ step: VisitClosing.Step) -> String {
        switch step {
        case .photos: text(LocalizedStringResource("followUpQueue.step.photos", defaultValue: "photos"))
        case .aftercare: text(LocalizedStringResource("followUpQueue.step.aftercare", defaultValue: "aftercare"))
        case .nextVisit: text(LocalizedStringResource("followUpQueue.step.nextVisit", defaultValue: "next visit"))
        }
    }

    // MARK: - Private

    /// "Thursday, October 15, 18:02".
    private func moment(_ date: Date) -> String {
        "\(formatters.weekdayDayMonth(date)), \(formatters.time(date))"
    }

    private func text(_ resource: LocalizedStringResource) -> String {
        resource.resolved(in: formatters.locale)
    }
}
