//
//  BlockTimeViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Block time sheet (6.6): which days, the whole day or some hours, a private reason, and
/// what to do with the visits already booked in the closed time. Saving closes the time (`TimeBlockService`) and,
/// when she chose to, cancels those visits **as the professional**, which never counts against a client (D13).
@MainActor
@Observable
final class BlockTimeViewModel {
    /// What a finished block did, for the confirmation.
    struct Outcome: Equatable {
        var blockedDays: Int
        /// The visits cancelled, so each client can be told.
        var cancelled: [Appointment]
        /// Visits that could not be cancelled (the block itself was saved).
        var failedCancellations: Int
        /// The visits that stay booked inside the blocked time.
        var kept: [Appointment]
    }

    enum Phase: Equatable {
        case editing
        case done(Outcome)
    }

    private(set) var phase = Phase.editing
    private(set) var candidateDays: [Date] = []
    private(set) var selectedDays: Set<Date>
    var scope = ScopeChoice.wholeDay
    private(set) var startMinutes = 9 * 60
    private(set) var endMinutes = 13 * 60
    var reason: BlockReason?
    var visitChoice = BlockPlanner.VisitChoice.cancelAndInvite
    private(set) var appointments: [Appointment] = []
    private(set) var clients: [UUID: Client] = [:]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var saveErrorMessage: String?
    private(set) var isSaving = false

    /// "Whole day" or "Some hours" of the segmented control.
    enum ScopeChoice: String, CaseIterable, Identifiable {
        case wholeDay
        case someHours
        var id: String { rawValue }
    }

    static let candidateDayCount = 14

    let days: CalendarDays
    private let timeBlocks: TimeBlockService
    private let appointmentService: AppointmentService
    private let bookingSetup: BookingSetupService
    private let vault: VaultService
    private let timeZoneID: String
    private let now: @Sendable () -> Date

    init(
        day: Date?, timeZoneID: String, firstWeekday: Int = 2,
        appointments: AppointmentService, timeBlocks: TimeBlockService, bookingSetup: BookingSetupService,
        vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let days = CalendarDays(timeZone: TimeZone(identifier: timeZoneID) ?? .current, firstWeekday: firstWeekday)
        self.days = days
        self.timeZoneID = timeZoneID
        appointmentService = appointments
        self.timeBlocks = timeBlocks
        self.bookingSetup = bookingSetup
        self.vault = vault
        self.now = now
        let first = days.start(of: day ?? now())
        candidateDays = (0..<Self.candidateDayCount).map { days.adding(days: $0, to: first) }
        selectedDays = [first]
    }

    // MARK: - Reading

    var availability: AvailabilitySettings { bookingSetup.availability }

    var plannedScope: BlockPlanner.Scope {
        scope == .wholeDay ? .wholeDay : .hours(startMinutes: startMinutes, endMinutes: endMinutes)
    }

    var issue: BlockPlanner.Issue? {
        BlockPlanner.issue(days: Array(selectedDays), scope: plannedScope)
    }

    /// The visits each day has inside the time that would be closed.
    var bookedCounts: [Date: Int] {
        BlockPlanner.bookedCounts(
            days: candidateDays, scope: plannedScope, appointments: appointments, settings: availability
        )
    }

    /// The visits the chosen days and hours touch.
    var affectedVisits: [Appointment] {
        BlockPlanner.affected(by: plannedBlocks(), appointments: appointments)
    }

    var cancelsVisits: Bool { visitChoice == .cancelAndInvite && !affectedVisits.isEmpty }

    var canSave: Bool { issue == nil && !isSaving && hasLoaded && errorMessage == nil }

    func clientName(for appointment: Appointment) -> String {
        clients[appointment.clientID]?.name ?? ""
    }

    // MARK: - Choosing

    func toggleDay(_ day: Date) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 { selectedDays.remove(day) }
        } else {
            selectedDays.insert(day)
        }
    }

    func setStart(minutes: Int) {
        startMinutes = minutes
        if endMinutes <= minutes { endMinutes = min(minutes + 60, 24 * 60) }
    }

    func setEnd(minutes: Int) {
        endMinutes = minutes
    }

    // MARK: - Loading

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        guard let first = candidateDays.first, let last = candidateDays.last else { return }
        do {
            try await bookingSetup.load(timeZoneID: timeZoneID)
            appointments = try await appointmentService.appointments(
                in: DateInterval(start: first, end: days.interval(of: last).end)
            )
            if let repository = vault.repository {
                clients = Dictionary(
                    uniqueKeysWithValues: try await repository.allClients().map { ($0.id, $0) }
                )
            }
        } catch {
            errorMessage = String(
                localized: "blockTime.error.load",
                defaultValue: "We could not read your calendar. Check that your iPhone is unlocked and try again."
            )
        }
    }

    // MARK: - Saving

    /// Closes the time. `reasonText` is the words of the chosen reason in her language.
    @discardableResult
    func saveAsync(reasonText: String?) async -> Bool {
        guard canSave else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }
        let blocks = BlockPlanner.blocks(
            days: Array(selectedDays), scope: plannedScope, reason: reasonText, settings: availability
        )
        let affected = BlockPlanner.affected(by: blocks, appointments: appointments)
        do {
            try await timeBlocks.block(blocks)
        } catch {
            saveErrorMessage = String(
                localized: "blockTime.error.save",
                defaultValue: "We could not block this time. Nothing was changed. Try again."
            )
            return false
        }
        var outcome = Outcome(blockedDays: blocks.count, cancelled: [], failedCancellations: 0, kept: affected)
        if visitChoice == .cancelAndInvite {
            outcome.kept = []
            let policy = bookingSetup.setup.cancellation
            for visit in affected {
                do {
                    let cancelled = try await appointmentService.cancel(
                        id: visit.id, by: .professional, policy: policy, now: now()
                    )
                    outcome.cancelled.append(cancelled)
                } catch {
                    outcome.failedCancellations += 1
                    outcome.kept.append(visit)
                }
            }
        }
        phase = .done(outcome)
        return true
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Private

    private func plannedBlocks() -> [TimeBlock] {
        BlockPlanner.blocks(days: Array(selectedDays), scope: plannedScope, reason: nil, settings: availability)
    }
}
