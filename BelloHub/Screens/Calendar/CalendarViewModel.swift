//
//  CalendarViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Calendar tab (2.3): the day she looks at, the day or week mode, and the visits and blocks
/// of that week, which the vault pushes after every change. The layout of a day is `CalendarDayLayout`'s; this class
/// only chooses which days to build and keeps the listeners running.
@MainActor
@Observable
final class CalendarViewModel {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case day
        case week
        var id: String { rawValue }
    }

    var mode = Mode.day
    /// The start of the day she looks at, in the business time zone.
    private(set) var selectedDay: Date
    private(set) var appointments: [Appointment] = []
    private(set) var blocks: [TimeBlock] = []
    private(set) var clients: [UUID: Client] = [:]
    /// True until the visits of the shown week have arrived once.
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    let days: CalendarDays
    private let appointmentService: AppointmentService
    private let timeBlockService: TimeBlockService
    private let bookingSetup: BookingSetupService
    private let vault: VaultService
    private let timeZoneID: String
    private let listeners = TaskBag()
    /// The week the visit and block listeners are running for.
    private var listeningWeek: DateInterval?

    init(
        timeZoneID: String, firstWeekday: Int = 2,
        appointments: AppointmentService, timeBlocks: TimeBlockService, bookingSetup: BookingSetupService,
        vault: VaultService, now: Date = Date()
    ) {
        let days = CalendarDays(timeZone: TimeZone(identifier: timeZoneID) ?? .current, firstWeekday: firstWeekday)
        self.days = days
        self.timeZoneID = timeZoneID
        appointmentService = appointments
        timeBlockService = timeBlocks
        self.bookingSetup = bookingSetup
        self.vault = vault
        selectedDay = days.start(of: now)
    }

    // MARK: - Reading

    /// Her hours, read in the zone this screen cuts its days in: a day chosen here gets that day's hours even when
    /// they were saved in another zone (`AvailabilitySettings.inTimeZone`).
    var availability: AvailabilitySettings { bookingSetup.availability.inTimeZone(days.calendar.timeZone) }

    /// The seven days of the week she is in.
    var weekDays: [Date] { days.week(containing: selectedDay) }

    var visibleMinutes: CalendarDayLayout.VisibleMinutes {
        CalendarDayLayout.visibleMinutes(
            settings: availability, appointments: weekAppointments, blocks: blocks, days: days
        )
    }

    /// What the seven days of the week share, so the week grid builds them against one hour scale.
    var scale: CalendarDayLayout.Scale {
        CalendarDayLayout.Scale(settings: availability, visible: visibleMinutes, days: days)
    }

    func layout(for day: Date) -> CalendarDayLayout {
        let interval = days.interval(of: day)
        return CalendarDayLayout.make(
            day: day, appointments: appointments.filter { $0.interval.intersection(with: interval) != nil },
            blocks: blocks.filter { $0.interval.intersection(with: interval) != nil }, scale: scale
        )
    }

    /// The visits of one day that the calendar shows, in time order.
    func visits(on day: Date) -> [Appointment] {
        let interval = days.interval(of: day)
        return appointments.filter { CalendarDayLayout.isShown($0) && $0.interval.intersection(with: interval) != nil }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func appointment(id: UUID) -> Appointment? {
        appointments.first { $0.id == id }
    }

    func clientName(of appointment: Appointment) -> String {
        clients[appointment.clientID]?.name ?? ""
    }

    func isToday(_ day: Date, now: Date) -> Bool {
        days.isSameDay(day, now)
    }

    var selectedWeekIsEmpty: Bool {
        !isLoading && weekAppointments.isEmpty
    }

    // MARK: - Navigation

    func select(day: Date) {
        let newDay = days.start(of: day)
        guard newDay != selectedDay else { return }
        selectedDay = newDay
        startListeningIfNeeded()
    }

    func goToToday(now: Date) {
        select(day: now)
    }

    /// Previous or next day in the day mode, week in the week mode.
    func step(forward: Bool) {
        let amount = mode == .day ? 1 : 7
        select(day: days.adding(days: forward ? amount : -amount, to: selectedDay))
    }

    // MARK: - Listening

    /// Starts watching the vault. Safe to call again (appearing, retrying): it only restarts what is not running.
    func startListening() {
        guard vault.isAvailable else {
            errorMessage = String(interface: LocalizedStringResource(
                "calendar.error.unavailable",
                defaultValue: "Your calendar is not available. Check that your iPhone is unlocked and try again."
            ))
            isLoading = false
            return
        }
        errorMessage = nil
        Task {
            _ = try? await bookingSetup.load(timeZoneID: timeZoneID)
        }
        startClientListener()
        startListeningIfNeeded()
    }

    /// Stops watching and forgets what was loaded, so a sign-out or a lock leaves nothing behind.
    func stopListening() {
        listeners.cancelAll()
        listeningWeek = nil
        clientsListenerRunning = false
        appointments = []
        blocks = []
        clients = [:]
        isLoading = true
    }

    // MARK: - Private

    private var clientsListenerRunning = false

    private var weekAppointments: [Appointment] {
        let week = days.weekInterval(containing: selectedDay)
        return appointments.filter { $0.interval.intersection(with: week) != nil }
    }

    private func startClientListener() {
        guard !clientsListenerRunning, let repository = vault.repository else { return }
        clientsListenerRunning = true
        listeners.add([Task { [weak self] in
            for await list in repository.clients() {
                guard let self, !Task.isCancelled else { return }
                clients = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            }
        }])
    }

    private func startListeningIfNeeded() {
        let week = days.weekInterval(containing: selectedDay)
        guard week != listeningWeek else { return }
        listeningWeek = week
        listeners.cancelAll()
        clientsListenerRunning = false
        startClientListener()
        isLoading = true
        let visits = appointmentService.stream(in: week)
        let closed = timeBlockService.stream(in: week)
        listeners.add([
            Task { [weak self] in
                for await list in visits {
                    guard let self, !Task.isCancelled else { return }
                    appointments = list
                    isLoading = false
                }
            },
            Task { [weak self] in
                for await list in closed {
                    guard let self, !Task.isCancelled else { return }
                    blocks = list
                }
            }
        ])
    }
}
