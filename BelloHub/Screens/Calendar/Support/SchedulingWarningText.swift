//
//  SchedulingWarningText.swift
//  BelloHub
//

import Foundation

/// The words of each `SchedulingWarning`. Neutral wording: no "she" for the client, so the sentences need no
/// agreement in the languages that would require one. Names go through `BidiIsolate`, times through `Formatters`.
struct SchedulingWarningText {
    enum Tone: Equatable, Sendable {
        /// A clinical or safety matter: coral.
        case safety
        /// The time does not fit her usual rules: amber.
        case warning
        /// Worth knowing: sage.
        case info
    }

    struct Entry: Equatable, Identifiable {
        let warning: SchedulingWarning
        let tone: Tone
        let title: LocalizedStringResource
        let message: LocalizedStringResource?
        /// For the accessibility identifier: `<screen>.warning.<key>`.
        let key: String

        var id: SchedulingWarning { warning }
    }

    let clientName: String
    let serviceName: String
    /// The client of a visit this one clashes with.
    let neighbourName: (UUID) -> String?
    let catalog: HealthFormCatalog?
    let formatters: Formatters

    func entries(for warnings: [SchedulingWarning]) -> [Entry] {
        warnings.map(entry)
    }

    func entry(for warning: SchedulingWarning) -> Entry {
        if let entry = timeEntry(warning) { return entry }
        return clientEntry(warning)
    }

    // MARK: - The time

    private func timeEntry(_ warning: SchedulingWarning) -> Entry? {
        switch warning {
        case .inThePast:
            return entry(warning, .warning, "inThePast",
                         LocalizedStringResource("scheduling.warning.inThePast.title",
                                                 defaultValue: "This time has already passed."),
                         LocalizedStringResource("scheduling.warning.inThePast.message",
                                                 defaultValue: "You can still book it, for example a past visit."))
        case .overlap(let id):
            return entry(warning, .warning, "overlap", overlapTitle(id),
                         LocalizedStringResource("scheduling.warning.overlap.message",
                                                 defaultValue: "Two appointments would be at the same time."))
        case .blocked:
            return entry(warning, .warning, "blocked",
                         LocalizedStringResource("scheduling.warning.blocked.title",
                                                 defaultValue: "This time is blocked."),
                         LocalizedStringResource("scheduling.warning.blocked.message",
                                                 defaultValue: "You closed it in your calendar."))
        case .dayOff:
            return entry(warning, .warning, "dayOff",
                         LocalizedStringResource("scheduling.warning.dayOff.title",
                                                 defaultValue: "This day is closed."),
                         LocalizedStringResource("scheduling.warning.dayOff.message",
                                                 defaultValue: "It is one of your days off."))
        case .closedDay:
            return entry(warning, .warning, "closedDay",
                         LocalizedStringResource("scheduling.warning.closedDay.title",
                                                 defaultValue: "You do not work this day."),
                         LocalizedStringResource("scheduling.warning.closedDay.message",
                                                 defaultValue: "It is outside your weekly hours."))
        case .outsideHours(let kind):
            return entry(warning, .warning, "outsideHours", outsideTitle(kind),
                         LocalizedStringResource("scheduling.warning.outside.message",
                                                 defaultValue: "It is outside your working hours."))
        case .insideBreak(let label):
            return entry(warning, .warning, "break",
                         LocalizedStringResource("scheduling.warning.break.title",
                                                 defaultValue: "It runs into \(BidiIsolate.wrap(label))."),
                         LocalizedStringResource("scheduling.warning.break.message",
                                                 defaultValue: "That time is one of your breaks."))
        case .buffer(let minutes, _):
            return entry(warning, .warning, "buffer",
                         LocalizedStringResource("scheduling.warning.buffer.title",
                                                 defaultValue: "Tight with the appointment next to it."),
                         LocalizedStringResource(
                             "scheduling.warning.buffer.message",
                             defaultValue: "You like \(formatters.minutes(minutes)) between appointments."))
        default:
            return nil
        }
    }

    private func overlapTitle(_ id: UUID) -> LocalizedStringResource {
        guard let other = neighbourName(id) else {
            return LocalizedStringResource("scheduling.warning.overlap.titleGeneric",
                                           defaultValue: "Overlaps with another appointment.")
        }
        return LocalizedStringResource("scheduling.warning.overlap.title",
                                       defaultValue: "Overlaps with \(BidiIsolate.wrap(other)).")
    }

    private func outsideTitle(_ kind: SchedulingWarning.OutsideHours) -> LocalizedStringResource {
        switch kind {
        case .beforeOpening:
            LocalizedStringResource("scheduling.warning.outside.before",
                                    defaultValue: "Starts before your working hours.")
        case .afterClosing:
            LocalizedStringResource("scheduling.warning.outside.after", defaultValue: "Ends after your working hours.")
        case .betweenStretches:
            LocalizedStringResource("scheduling.warning.outside.between",
                                    defaultValue: "Falls between your working stretches.")
        }
    }

    // MARK: - The client and the service

    private func clientEntry(_ warning: SchedulingWarning) -> Entry {
        let client = BidiIsolate.wrap(clientName)
        let service = BidiIsolate.wrap(serviceName)
        switch warning {
        case .missingPatchTest(let hours):
            return entry(warning, .safety, "patchTest",
                         LocalizedStringResource("scheduling.warning.patchTest.title",
                                                 defaultValue: "No patch test on record for \(client)."),
                         LocalizedStringResource(
                             "scheduling.warning.patchTest.message",
                             defaultValue: "\(service) asks for one at least \(formatters.hours(hours)) before."))
        case .patchTestReaction:
            return entry(warning, .safety, "patchTestReaction",
                         LocalizedStringResource("scheduling.warning.patchReaction.title",
                                                 defaultValue: "The latest patch test of \(client) showed a reaction."),
                         LocalizedStringResource("scheduling.warning.patchReaction.message",
                                                 defaultValue: "Review it before you treat."))
        case .contraindicated(let matches):
            return entry(warning, .safety, "contraindication",
                         LocalizedStringResource("scheduling.warning.contraindication.title",
                                                 defaultValue: "Review the health form first."),
                         LocalizedStringResource(
                             "scheduling.warning.contraindication.message",
                             defaultValue: "\(service) is marked not suitable for: \(matchNames(matches))."))
        case .noHealthForm:
            return entry(warning, .info, "noHealthForm",
                         LocalizedStringResource("scheduling.warning.noForm.title",
                                                 defaultValue: "No health form on record for \(client)."),
                         LocalizedStringResource("scheduling.warning.noForm.message",
                                                 defaultValue: "\(service) lists contraindications to check."))
        default:
            return entry(warning, .info, "cancelsOften",
                         LocalizedStringResource("scheduling.warning.cancelsOften.title",
                                                 defaultValue: "\(client) cancels or misses appointments often."),
                         LocalizedStringResource("scheduling.warning.cancelsOften.message",
                                                 defaultValue: "A reminder the day before may help."))
        }
    }

    // MARK: - Private

    private func entry(
        _ warning: SchedulingWarning, _ tone: Tone, _ key: String, _ title: LocalizedStringResource,
        _ message: LocalizedStringResource?
    ) -> Entry {
        Entry(warning: warning, tone: tone, title: title, message: message, key: key)
    }

    /// "Pregnancy, Allergies: Latex": the question (and choice) each matched token names, in the form's language.
    private func matchNames(_ matches: [ContraindicationReport.Match]) -> String {
        let names = matches.map { match -> String in
            guard let questionKey = match.questionKey, let question = catalog?.question(for: questionKey) else {
                return String(localized: LocalizedStringResource(
                    "scheduling.warning.contraindication.minor", defaultValue: "Under 18", locale: formatters.locale
                ))
            }
            guard let optionKey = match.optionKey, let option = question.optionName(for: optionKey) else {
                return question.name
            }
            return "\(question.name): \(option)"
        }
        return formatters.list(names)
    }
}
