//
//  AvailabilityEditorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AvailabilityEditor")
struct AvailabilityEditorTests {
    /// Tuesday to Saturday, 09:00 to 19:00, lunch every day, the prototype's week.
    private let maria = makeAvailability()

    private func draft(_ start: Int, _ end: Int) -> StretchDraft {
        StretchDraft(startMinutes: start, endMinutes: end)
    }

    // MARK: - Weekdays

    @Test("The week starts on the day the region starts it")
    func weekOrder() {
        #expect(AvailabilityEditor.weekdays(firstWeekday: 1) == [1, 2, 3, 4, 5, 6, 7])
        #expect(AvailabilityEditor.weekdays(firstWeekday: 2) == [2, 3, 4, 5, 6, 7, 1])
        #expect(AvailabilityEditor.weekdays(firstWeekday: 7) == [7, 1, 2, 3, 4, 5, 6])
        #expect(AvailabilityEditor.weekdays(firstWeekday: 0) == [1, 2, 3, 4, 5, 6, 7], "out of range falls back")
        #expect(AvailabilityEditor.weekdays(firstWeekday: 9) == [7, 1, 2, 3, 4, 5, 6])
    }

    @Test("A weekday is open when it has a stretch")
    func isOpen() {
        #expect(AvailabilityEditor.isOpen(3, in: maria))
        #expect(!AvailabilityEditor.isOpen(1, in: maria) && !AvailabilityEditor.isOpen(2, in: maria))
    }

    @Test("Switching a closed day on gives it 09:00 to 18:00")
    func switchOn() {
        let updated = AvailabilityEditor.setting(2, open: true, in: maria)
        #expect(AvailabilityEditor.stretches(for: 2, in: updated) == [AvailabilityRule(weekday: 2, startMinutes: 540,
            endMinutes: 1080)])
        #expect(updated.weekly.count == maria.weekly.count + 1)
    }

    @Test("Switching a day off removes its stretches and leaves the others")
    func switchOff() {
        let updated = AvailabilityEditor.setting(4, open: false, in: maria)
        #expect(!AvailabilityEditor.isOpen(4, in: updated))
        #expect(updated.weekly.count == maria.weekly.count - 1)
        #expect(updated.breaks == maria.breaks && updated.bufferMinutes == maria.bufferMinutes)
    }

    @Test("Switching a day back on restores the hours it had")
    func restore() {
        let split = AvailabilityEditor.replacingStretches(of: 3, with: [draft(540, 720), draft(840, 1140)], in: maria)
        guard case .success(let settings) = split else {
            Issue.record("split day rejected")
            return
        }
        let before = AvailabilityEditor.stretches(for: 3, in: settings)
        let off = AvailabilityEditor.setting(3, open: false, in: settings)
        let on = AvailabilityEditor.setting(3, open: true, in: off, restoring: before)
        #expect(AvailabilityEditor.stretches(for: 3, in: on) == before)
    }

    // MARK: - Stretches

    @Test("A day can have a morning and an evening, kept in order")
    func twoStretches() {
        let result = AvailabilityEditor.replacingStretches(of: 6, with: [draft(840, 1200), draft(540, 720)], in: maria)
        guard case .success(let updated) = result else {
            Issue.record("rejected")
            return
        }
        let stretches = AvailabilityEditor.stretches(for: 6, in: updated)
        #expect(stretches.map(\.startMinutes) == [540, 840] && stretches.map(\.endMinutes) == [720, 1200])
        #expect(updated.weekly.count == maria.weekly.count + 1)
    }

    @Test("A stretch must end after it starts, last 15 minutes and not overlap another")
    func stretchIssues() {
        #expect(AvailabilityEditor.issue(in: [draft(600, 600)]) == .order)
        #expect(AvailabilityEditor.issue(in: [draft(700, 600)]) == .order)
        #expect(AvailabilityEditor.issue(in: [draft(600, 610)]) == .tooShort)
        #expect(AvailabilityEditor.issue(in: [draft(600, 615)]) == nil)
        #expect(AvailabilityEditor.issue(in: [draft(540, 720), draft(700, 900)]) == .overlap)
        #expect(AvailabilityEditor.issue(in: [draft(540, 720), draft(720, 900)]) == nil, "touching is not overlapping")
        #expect(AvailabilityEditor.issue(in: [draft(540, 720), draft(840, 1200)]) == nil)
        #expect(AvailabilityEditor.issue(in: []) == nil)
    }

    @Test("A rejected edit changes nothing")
    func rejected() {
        let result = AvailabilityEditor.replacingStretches(of: 3, with: [draft(900, 600)], in: maria)
        #expect(result == .failure(.order))
    }

    @Test("A stretch can run to midnight")
    func untilMidnight() {
        let result = AvailabilityEditor.replacingStretches(of: 6, with: [draft(1080, 1440)], in: maria)
        #expect((try? result.get().weekly.contains { $0.weekday == 6 && $0.endMinutes == 1440 }) == true)
    }

    // MARK: - Breaks

    @Test("A new break is added; an edited one is replaced in place")
    func breaks() throws {
        let coffee = BreakRule(weekday: nil, startMinutes: 990, endMinutes: 1005, label: "Coffee break")
        let added = try AvailabilityEditor.savingBreak(coffee, at: nil, fallbackLabel: "Break", in: maria).get()
        #expect(added.breaks.count == 2 && added.breaks[1] == coffee)

        var moved = coffee
        moved.startMinutes = 1000
        moved.endMinutes = 1030
        let edited = try AvailabilityEditor.savingBreak(moved, at: 1, fallbackLabel: "Break", in: added).get()
        #expect(edited.breaks.count == 2 && edited.breaks[1] == moved)
    }

    @Test("A break must end after it starts")
    func breakOrder() {
        let bad = BreakRule(weekday: nil, startMinutes: 800, endMinutes: 800, label: "Lunch")
        #expect(AvailabilityEditor.savingBreak(bad, at: nil, fallbackLabel: "Break", in: maria) == .failure(.order))
    }

    @Test("A blank name becomes the fallback and a long one is cut")
    func breakNames() throws {
        let blank = BreakRule(weekday: 3, startMinutes: 600, endMinutes: 615, label: "   ")
        #expect(try AvailabilityEditor.savingBreak(blank, at: nil, fallbackLabel: "Break",
            in: maria).get().breaks.last?.label == "Break")
        let long = BreakRule(weekday: 3, startMinutes: 600, endMinutes: 615, label: String(repeating: "x", count: 80))
        #expect(try AvailabilityEditor.savingBreak(long, at: nil, fallbackLabel: "Break",
            in: maria).get().breaks.last?.label.count == 30)
    }

    @Test("No more than 28 breaks are stored")
    func breakLimit() throws {
        var settings = maria
        settings.breaks = (0..<28).map { BreakRule(weekday: nil, startMinutes: $0 * 10, endMinutes: $0 * 10 + 5,
            label: "b") }
        let one = BreakRule(weekday: nil, startMinutes: 1000, endMinutes: 1010, label: "x")
        #expect(try AvailabilityEditor.savingBreak(one, at: nil, fallbackLabel: "Break",
            in: settings).get().breaks.count == 28)
    }

    @Test("Breaks are listed every-day first, then by weekday and time, and removing one uses its stored place")
    func breakOrderAndRemoval() throws {
        var settings = maria
        settings.breaks = [
            BreakRule(weekday: 5, startMinutes: 600, endMinutes: 615, label: "Fri"),
            BreakRule(weekday: nil, startMinutes: 900, endMinutes: 915, label: "All late"),
            BreakRule(weekday: nil, startMinutes: 750, endMinutes: 810, label: "All early")
        ]
        let listed = AvailabilityEditor.sortedBreaks(settings)
        #expect(listed.map(\.rule.label) == ["All early", "All late", "Fri"])
        #expect(listed.map(\.index) == [2, 1, 0])
        let removed = AvailabilityEditor.removingBreak(at: 2, from: settings)
        #expect(removed.breaks.map(\.label) == ["Fri", "All late"])
        #expect(AvailabilityEditor.removingBreak(at: 9, from: settings) == settings)
    }

    // MARK: - Days off

    private func dayOff(_ start: String, _ end: String, kind: DayOffKind = .vacation, id: UUID = UUID()) -> DayOff {
        DayOff(id: id, startDate: TestClock.date("\(start) 15:00"), endDate: TestClock.date("\(end) 08:00"), kind: kind)
    }

    @Test("Days off are stored as whole days in the business zone, first to last")
    func daysOffNormalized() throws {
        let updated = try AvailabilityEditor.savingDayOff(dayOff("2026-12-22", "2027-01-05"), now: TestClock.now,
            in: maria).get()
        #expect(updated.daysOff.count == 1)
        #expect(updated.daysOff[0].startDate == TestClock.date("2026-12-22 00:00"))
        #expect(updated.daysOff[0].endDate == TestClock.date("2027-01-05 00:00"))
    }

    @Test("The last day cannot be before the first")
    func daysOffOrder() {
        #expect(AvailabilityEditor.savingDayOff(dayOff("2026-12-22", "2026-12-20"), now: TestClock.now, in: maria)
            == .failure(.order))
    }

    @Test("Editing days off replaces them; past ones are dropped on save")
    func daysOffEdit() throws {
        let past = dayOff("2026-08-01", "2026-08-10")
        let first = dayOff("2026-12-22", "2026-12-24")
        var settings = maria
        settings.daysOff = [past, first]
        let edited = DayOff(id: first.id, startDate: first.startDate, endDate: TestClock.date("2026-12-31 00:00"),
            kind: .blocked)
        let updated = try AvailabilityEditor.savingDayOff(edited, now: TestClock.now, in: settings).get()
        #expect(updated.daysOff.map(\.id) == [first.id])
        #expect(updated.daysOff[0].kind == .blocked && updated.daysOff[0].endDate == TestClock.date("2026-12-31 00:00"))
    }

    @Test("Only days off that are not over are listed, soonest first")
    func upcoming() {
        var settings = maria
        let later = dayOff("2026-12-22", "2027-01-05")
        let soon = dayOff("2026-10-12", "2026-10-12", kind: .dayOff)
        let past = dayOff("2026-08-01", "2026-08-10")
        let today = dayOff("2026-09-30", "2026-10-01")
        settings.daysOff = [later, past, soon, today]
        let listed = AvailabilityEditor.upcomingDaysOff(settings, now: TestClock.now)
        #expect(listed.map(\.id) == [today.id, soon.id, later.id])
    }

    @Test("Removing days off by id")
    func removeDayOff() {
        var settings = maria
        let one = dayOff("2026-12-22", "2026-12-24")
        let two = dayOff("2026-11-02", "2026-11-02")
        settings.daysOff = [one, two]
        #expect(AvailabilityEditor.removingDayOff(id: one.id, from: settings).daysOff.map(\.id) == [two.id])
    }

    // MARK: - Options

    @Test("The menus offer sensible values in order")
    func options() {
        #expect(AvailabilityEditor.bufferOptions == AvailabilityEditor.bufferOptions.sorted())
        #expect(AvailabilityEditor.bufferOptions.contains(AvailabilitySettings.defaultBufferMinutes))
        #expect(AvailabilityEditor.minNoticeOptions.contains(AvailabilitySettings.defaultMinNoticeHours))
        #expect(AvailabilityEditor.windowOptions.contains(AvailabilitySettings.defaultMaxDaysAhead))
    }
}
