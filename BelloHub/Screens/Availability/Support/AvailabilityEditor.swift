//
//  AvailabilityEditor.swift
//  BelloHub
//

import Foundation

/// Every rule for changing her availability, pure so it is tested and no View or ViewModel repeats it: switching a
/// weekday on or off, editing its stretches, breaks and days off, and the limits the server also enforces
/// (`publishAvailability`: at most 56 stretches, 28 breaks and 100 days off).
enum AvailabilityEditor {
    static let minimumStretchMinutes = 15
    static let maxStretchesPerDay = 4
    static let maxBreaks = 28
    static let maxDaysOff = 100
    /// What a day gets when she switches it on and it had no hours: the starting week's 09:00 to 18:00.
    static let defaultStretch = (start: 9 * 60, end: 18 * 60)

    static let bufferOptions = [0, 5, 10, 15, 20, 30, 45, 60]
    static let minNoticeOptions = [0, 1, 2, 4, 12, 24, 48]
    static let windowOptions = [14, 30, 60, 90, 180]

    // MARK: - Weekdays

    /// The weekdays in the order a week is drawn: starting from `firstWeekday` (1 is Sunday).
    static func weekdays(firstWeekday: Int) -> [Int] {
        let start = min(max(firstWeekday, 1), 7)
        return (0..<7).map { (start - 1 + $0) % 7 + 1 }
    }

    /// The stretches of one weekday, earliest first.
    static func stretches(for weekday: Int, in settings: AvailabilitySettings) -> [AvailabilityRule] {
        settings.weekly.filter { $0.weekday == weekday }.sorted { $0.startMinutes < $1.startMinutes }
    }

    static func isOpen(_ weekday: Int, in settings: AvailabilitySettings) -> Bool {
        settings.weekly.contains { $0.weekday == weekday }
    }

    /// Switches a weekday on or off. Switching on gives it `defaultStretch` when nothing remembers better; switching
    /// off removes its stretches (breaks that applied only to it stay: they matter again when it opens).
    static func setting(
        _ weekday: Int, open: Bool, in settings: AvailabilitySettings, restoring previous: [AvailabilityRule] = []
    ) -> AvailabilitySettings {
        var updated = settings
        updated.weekly.removeAll { $0.weekday == weekday }
        guard open else { return updated }
        let restored = previous.filter { $0.weekday == weekday }
        updated.weekly += restored.isEmpty
            ? [AvailabilityRule(weekday: weekday, startMinutes: defaultStretch.start, endMinutes: defaultStretch.end)]
            : restored
        return updated
    }

    /// Replaces the stretches of one weekday, or says why they cannot be saved.
    static func replacingStretches(
        of weekday: Int, with drafts: [StretchDraft], in settings: AvailabilitySettings
    ) -> Result<AvailabilitySettings, AvailabilityIssue> {
        if let issue = issue(in: drafts) { return .failure(issue) }
        var updated = settings
        updated.weekly.removeAll { $0.weekday == weekday }
        updated.weekly += drafts.sorted { $0.startMinutes < $1.startMinutes }.map {
            AvailabilityRule(weekday: weekday, startMinutes: $0.startMinutes, endMinutes: $0.endMinutes)
        }
        return .success(updated)
    }

    /// The first problem with a day's stretches, or nil.
    static func issue(in drafts: [StretchDraft]) -> AvailabilityIssue? {
        for draft in drafts where draft.endMinutes <= draft.startMinutes { return .order }
        for draft in drafts where draft.endMinutes - draft.startMinutes < minimumStretchMinutes { return .tooShort }
        let sorted = drafts.sorted { $0.startMinutes < $1.startMinutes }
        for (earlier, later) in zip(sorted, sorted.dropFirst()) where later.startMinutes < earlier.endMinutes {
            return .overlap
        }
        return nil
    }

    // MARK: - Breaks

    /// Breaks in the order they are listed: every-day ones first, then by weekday, then by start.
    static func sortedBreaks(_ settings: AvailabilitySettings) -> [(index: Int, rule: BreakRule)] {
        settings.breaks.enumerated().map { (index: $0.offset, rule: $0.element) }.sorted {
            let lhs = ($0.rule.weekday ?? 0, $0.rule.startMinutes, $0.index)
            let rhs = ($1.rule.weekday ?? 0, $1.rule.startMinutes, $1.index)
            return lhs < rhs
        }
    }

    /// The break at `index` replaced (or a new one added when `index` is nil), or why it cannot be saved. A blank name
    /// becomes `fallbackLabel`.
    static func savingBreak(
        _ rule: BreakRule, at index: Int?, fallbackLabel: String, in settings: AvailabilitySettings
    ) -> Result<AvailabilitySettings, AvailabilityIssue> {
        guard rule.endMinutes > rule.startMinutes else { return .failure(.order) }
        var stored = rule
        let label = rule.label.trimmingCharacters(in: .whitespacesAndNewlines)
        stored.label = label.isEmpty ? fallbackLabel : String(label.prefix(30))
        var updated = settings
        if let index, updated.breaks.indices.contains(index) {
            updated.breaks[index] = stored
        } else if updated.breaks.count < maxBreaks {
            updated.breaks.append(stored)
        }
        return .success(updated)
    }

    static func removingBreak(at index: Int, from settings: AvailabilitySettings) -> AvailabilitySettings {
        var updated = settings
        if updated.breaks.indices.contains(index) { updated.breaks.remove(at: index) }
        return updated
    }

    // MARK: - Days off

    /// Days off that are not over yet, soonest first. A past one is not shown and is dropped the next time days off
    /// are saved.
    static func upcomingDaysOff(_ settings: AvailabilitySettings, now: Date) -> [DayOff] {
        let today = calendar(for: settings).startOfDay(for: now)
        return settings.daysOff.filter { $0.endDate >= today }
            .sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }
    }

    /// Stores `dayOff` (a new one or an edit), normalised to whole days in the business zone, or says why it cannot be.
    static func savingDayOff(
        _ dayOff: DayOff, now: Date, in settings: AvailabilitySettings
    ) -> Result<AvailabilitySettings, AvailabilityIssue> {
        let calendar = calendar(for: settings)
        let first = calendar.startOfDay(for: dayOff.startDate)
        let last = calendar.startOfDay(for: dayOff.endDate)
        guard last >= first else { return .failure(.order) }
        var updated = settings
        let today = calendar.startOfDay(for: now)
        updated.daysOff.removeAll { $0.id == dayOff.id || $0.endDate < today }
        if updated.daysOff.count < maxDaysOff {
            updated.daysOff.append(DayOff(id: dayOff.id, startDate: first, endDate: last, kind: dayOff.kind))
        }
        return .success(updated)
    }

    static func removingDayOff(id: UUID, from settings: AvailabilitySettings) -> AvailabilitySettings {
        var updated = settings
        updated.daysOff.removeAll { $0.id == id }
        return updated
    }

    // MARK: - Private

    private static func calendar(for settings: AvailabilitySettings) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        return calendar
    }
}
