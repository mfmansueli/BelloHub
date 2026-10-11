//
//  HealthFormTemplateRules.swift
//  BelloHub
//

import Foundation

/// The rules of the health form, with no IO and no clock of their own (every date comes in as `now` or from the
/// form): which questions a profession is offered, what the first template is, when editing creates a new version,
/// and when a client's answers are due for review. One owner for each rule; the screens only call these.
enum HealthFormTemplateRules {
    /// "Ask again every" choices, in months.
    static let reviewOptions = [3, 6, 12, 24]
    static let defaultReviewMonths = 12

    // MARK: - Which questions

    /// A professional with no profession yet (it is chosen in the setup) is offered what `other` gets.
    private static func effective(_ professions: [ProfessionID]) -> [ProfessionID] {
        professions.isEmpty ? [.other] : professions
    }

    static func applies(_ question: HealthQuestion, to professions: [ProfessionID]) -> Bool {
        guard !question.professions.isEmpty else { return true }
        let own = effective(professions)
        return question.professions.contains { own.contains($0) }
    }

    /// The questions offered to a set of professions, in catalog order: what the editor lists.
    static func applicableQuestions(
        in catalog: HealthFormCatalog, for professions: [ProfessionID]
    ) -> [HealthQuestion] {
        catalog.questions.filter { applies($0, to: professions) }
    }

    /// The editor's list: what applies to her professions plus anything the template already asks, so a question she
    /// switched on never disappears because she later dropped a profession.
    static func offeredQuestions(
        in catalog: HealthFormCatalog, for professions: [ProfessionID], template: HealthFormTemplate?
    ) -> [HealthQuestion] {
        catalog.questions.filter { applies($0, to: professions) || template?.asks($0.key) == true }
    }

    /// The keys that start on for a set of professions.
    static func defaultKeys(in catalog: HealthFormCatalog, for professions: [ProfessionID]) -> [String] {
        applicableQuestions(in: catalog, for: professions).filter(\.isOnByDefault).map(\.key)
    }

    /// Version 1, built from her professions. It becomes a stored version the first time it is used.
    static func defaultTemplate(
        in catalog: HealthFormCatalog, for professions: [ProfessionID], now: Date
    ) -> HealthFormTemplate {
        HealthFormTemplate(
            version: 1, questionKeys: defaultKeys(in: catalog, for: professions),
            reviewEveryMonths: defaultReviewMonths, createdAt: now
        )
    }

    // MARK: - Versions

    /// The template after an edit. Changing which questions are on creates the **next version** (the old one stays,
    /// because forms signed on it refer to it); changing only "ask again every" updates the current version, which
    /// the clients' answers do not depend on. The same set of questions and the same months returns `current`.
    static func edited(
        _ current: HealthFormTemplate,
        enabling keys: Set<String>,
        reviewEveryMonths: Int,
        in catalog: HealthFormCatalog,
        now: Date
    ) -> HealthFormTemplate {
        let known = Set(catalog.questions.map(\.key))
        let chosen = catalog.questions.map(\.key).filter(keys.contains)
        let preserved = current.questionKeys.filter { !known.contains($0) }
        let newKeys = chosen + preserved
        let months = reviewOptions.contains(reviewEveryMonths) ? reviewEveryMonths : current.reviewEveryMonths

        if Set(newKeys) == Set(current.questionKeys) {
            guard months != current.reviewEveryMonths else { return current }
            var updated = current
            updated.reviewEveryMonths = months
            updated.updatedAt = now
            return updated
        }
        return HealthFormTemplate(version: current.version + 1, questionKeys: newKeys,
                                  reviewEveryMonths: months, createdAt: now)
    }

    /// Whether a repository may store `incoming` when a version with the same number is already stored. A stored
    /// version keeps its questions for good: forms signed on it are read against them. Both implementations of
    /// `FormTemplateRepository` ask this, so the rule has one owner.
    static func accepts(_ incoming: HealthFormTemplate, over existing: HealthFormTemplate?) -> Bool {
        guard let existing else { return true }
        return existing.questionKeys == incoming.questionKeys
    }

    /// The most recent version.
    static func current(of templates: [HealthFormTemplate]) -> HealthFormTemplate? {
        templates.max { $0.version < $1.version }
    }

    /// The version a form was signed on, if it is still stored.
    static func template(forVersion version: Int, in templates: [HealthFormTemplate]) -> HealthFormTemplate? {
        templates.first { $0.version == version }
    }

    // MARK: - Review

    /// `signedAt` plus `months` calendar months, counted on the wall clock of `calendar` (the business time zone), so
    /// a form signed at 10:00 is due at 10:00 even when a daylight-saving change falls in between. A month that is
    /// shorter clamps (Jan 31 plus one month is Feb 28).
    static func reviewDueDate(signedAt: Date, months: Int, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .month, value: months, to: signedAt)
    }

    /// Due **at** the instant the period ends, not after it: one second before is still current.
    static func reviewStatus(signedAt: Date?, months: Int, now: Date, calendar: Calendar) -> HealthReviewStatus {
        guard let signedAt, let dueAt = reviewDueDate(signedAt: signedAt, months: months, calendar: calendar) else {
            return .undated
        }
        return now >= dueAt ? .due(dueAt: dueAt) : .current(dueAt: dueAt)
    }

    /// The form the professional reads first: the one signed last. A form without a date comes after every dated one.
    static func latestForm(in forms: [HealthForm]) -> HealthForm? {
        forms.max { left, right in
            let leftDate = left.signedAt ?? .distantPast
            let rightDate = right.signedAt ?? .distantPast
            return (leftDate, left.formVersion) < (rightDate, right.formVersion)
        }
    }
}
