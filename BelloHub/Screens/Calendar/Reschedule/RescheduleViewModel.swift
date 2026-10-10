//
//  RescheduleViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Reschedule sheet (3.4): the next days that have room for this visit, the free times of the
/// chosen day, and the move itself through `AppointmentService.reschedule` (which keeps the visit's length, counts the
/// move and puts it back to "booked"). A time outside the free ones can still be typed; the engine then warns.
@MainActor
@Observable
final class RescheduleViewModel {
    enum Phase: Equatable {
        case loading
        case notFound
        case choosing
        case moved(Appointment)
    }

    private(set) var phase = Phase.loading
    private(set) var appointment: Appointment?
    private(set) var client: Client?
    private(set) var day: Date
    private(set) var start: Date?
    /// The days that have a free start for this visit, with their times, soonest first.
    private(set) var offeredDays: [(day: Date, slots: [Date])] = []
    private(set) var context = SchedulingContext.empty
    /// Her services, for the extra and processing time of each visit (D56).
    private(set) var services: [Service] = []
    var messagesClient = true
    private(set) var errorMessage: String?
    private(set) var saveErrorMessage: String?
    private(set) var isSaving = false

    let days: CalendarDays
    let appointmentID: UUID
    private let appointments: AppointmentService
    private let bookingSetup: BookingSetupService
    private let vault: VaultService
    private let loader: SchedulingContextLoader
    private let timeZoneID: String
    private let now: @Sendable () -> Date
    private var contextGeneration = 0

    /// How many days with a free time are offered.
    static let offeredDayCount = 8

    init(
        appointmentID: UUID, timeZoneID: String, firstWeekday: Int = 2,
        appointments: AppointmentService, timeBlocks: TimeBlockService, bookingSetup: BookingSetupService,
        vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let days = CalendarDays(timeZone: TimeZone(identifier: timeZoneID) ?? .current, firstWeekday: firstWeekday)
        self.days = days
        self.appointmentID = appointmentID
        self.timeZoneID = timeZoneID
        self.appointments = appointments
        self.bookingSetup = bookingSetup
        self.vault = vault
        loader = SchedulingContextLoader(
            appointments: appointments, timeBlocks: timeBlocks, vault: vault,
            catalogProvider: BundleHealthFormCatalogProvider(), localization: .en
        )
        self.now = now
        day = days.start(of: now())
    }

    // MARK: - Reading

    var availability: AvailabilitySettings { bookingSetup.availability }

    /// The free starts of the chosen day for this visit (D56: her slot interval, extra and processing time).
    var slotPlan: FreeSlotsPlan {
        guard let appointment else { return .empty }
        return OpenTimes.plan(on: day, request(for: appointment))
    }

    /// The times suggested first: with "Keep my day compact", the ones that leave no gap nobody can book.
    var slots: [Date] { slotPlan.recommended }

    /// The other free times, behind "Show all times".
    var moreSlots: [Date] { slotPlan.more }

    /// The warnings about the chosen time (the client's health does not change by moving the visit).
    var warnings: [SchedulingWarning] {
        guard let appointment, let start else { return [] }
        return SchedulingWarningEngine.warnings(for: SchedulingWarningInput(
            interval: DateInterval(start: start, duration: TimeInterval(appointment.totalMinutes * 60)),
            settings: availability, appointments: context.appointments, blocks: context.blocks, service: nil,
            clientID: nil, ignoring: appointment.id, now: now(), services: services, timing: timing(of: appointment)
        ))
    }

    var hasScheduleConflict: Bool { warnings.contains { $0.isScheduleConflict } }

    var canConfirm: Bool { start != nil && appointment != nil && !isSaving }

    /// True when the chosen time is not the visit's current one.
    var changesTime: Bool { start != nil && start != appointment?.startsAt }

    // MARK: - Loading

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard phase == .loading || phase == .notFound else { return }
        phase = .loading
        errorMessage = nil
        do {
            guard let found = try await appointments.appointment(id: appointmentID) else {
                phase = .notFound
                return
            }
            appointment = found
            if let repository = vault.repository {
                client = try? await repository.client(id: found.clientID)
                services = (try? await repository.services()) ?? []
            }
            try await bookingSetup.load(timeZoneID: timeZoneID)
            let today = days.start(of: now())
            let horizon = DateInterval(start: days.adding(days: -1, to: today), end: days.adding(days: 50, to: today))
            context = try await loader.load(range: horizon, clientID: nil)
            offeredDays = OpenTimes.nextDays(
                from: today, count: Self.offeredDayCount, days: days, request(for: found)
            )
            day = offeredDays.first?.day ?? today
            phase = .choosing
        } catch {
            errorMessage = String(
                localized: "reschedule.error.load",
                defaultValue: "We could not read this appointment. Check that your iPhone is unlocked and try again."
            )
            phase = .notFound
        }
    }

    // MARK: - Choosing

    func selectDay(_ date: Date) {
        let newDay = days.start(of: date)
        guard newDay != day else { return }
        day = newDay
        start = nil
        Task { await refreshAround(newDay) }
    }

    func selectStart(_ date: Date) {
        start = date
    }

    func selectTime(minutes: Int) {
        start = days.date(on: day, minutes: minutes)
    }

    // MARK: - Moving

    @discardableResult
    func confirmAsync() async -> Bool {
        guard canConfirm, let start else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }
        do {
            let moved = try await appointments.reschedule(id: appointmentID, to: start, now: now())
            appointment = moved
            phase = .moved(moved)
            return true
        } catch {
            saveErrorMessage = String(
                localized: "reschedule.error.save",
                defaultValue: "We could not move this appointment. Nothing was changed. Try again."
            )
            return false
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Private

    private func request(for appointment: Appointment) -> OpenTimes.Request {
        OpenTimes.Request(
            durationMinutes: appointment.totalMinutes, settings: availability, appointments: context.appointments,
            blocks: context.blocks, now: now(), ignoring: appointment.id, services: services,
            timing: timing(of: appointment)
        )
    }

    /// The moved visit keeps the shape of its service (none when the service is gone).
    private func timing(of appointment: Appointment) -> VisitTiming {
        services.first { $0.id == appointment.serviceID }?.visitTiming ?? .noExtraTime
    }

    /// A day outside the offered window (picked with the date picker) needs its own surroundings.
    private func refreshAround(_ chosen: Date) async {
        contextGeneration += 1
        let generation = contextGeneration
        let range = DateInterval(start: days.adding(days: -1, to: chosen), end: days.adding(days: 2, to: chosen))
        guard let near = try? await loader.surroundings(of: range), generation == contextGeneration else { return }
        let known = Set(context.appointments.map(\.id))
        context.appointments += near.appointments.filter { !known.contains($0.id) }
        let knownBlocks = Set(context.blocks.map(\.id))
        context.blocks += near.blocks.filter { !knownBlocks.contains($0.id) }
    }
}
