//
//  NoShowMarkViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the no-show sheet (3.7): count the miss or excuse it (D13), see what that does to the client's
/// count, and optionally open a friendly note in her chat after saving.
@MainActor
@Observable
final class NoShowMarkViewModel {
    struct Done: Equatable {
        let forgiven: Bool
        /// Nil when she chose not to send a note.
        let message: MessageService.Outcome?
    }

    let appointmentID: UUID
    private(set) var visit: VisitContext?
    private(set) var projection: NoShowProjection?
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var actionErrorMessage: String?
    private(set) var isWorking = false
    private(set) var done: Done?
    /// True counts toward her limit; false is an excused absence (she told me, or it was a good reason).
    var countsAgainstClient = true
    var sendsNote = true

    private let appointments: AppointmentService
    private let vault: VaultService
    private let profile: ProfileService
    private let setup: BookingSetupService
    private let messages: MessageService
    private let now: @Sendable () -> Date

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appointmentID = appointmentID
        self.appointments = appointments
        self.vault = vault
        self.profile = profile
        self.setup = setup
        self.messages = messages
        self.now = now
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    /// A visit that has not started cannot be missed, and a closed one is already decided.
    var canMark: Bool {
        guard let appointment = visit?.appointment else { return false }
        return AppointmentActionRules.layout(for: appointment, now: now()).all.contains(.noShow)
    }

    var policy: NoShowPolicy {
        setup.setup.noShow
    }

    /// The status the card shows: with the miss counted, or as it is now when she excuses it.
    var shownStatus: NoShowStatus? {
        guard let projection else { return nil }
        return countsAgainstClient ? projection.after : projection.before
    }

    /// Counting this one is what takes her to the limit.
    var reachesLimit: Bool {
        countsAgainstClient && (projection?.reachesLimit ?? false)
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        let reader = VisitReader(appointments: appointments, vault: vault)
        do {
            guard let loaded = try await reader.visit(id: appointmentID) else {
                isMissing = true
                isLoading = false
                return
            }
            if !setup.hasLoaded { try? await setup.load(timeZoneID: business.timeZone.identifier) }
            let history = try await reader.history(of: loaded.client.id)
            projection = NoShowProjection.make(
                NoShowProjection.Input(
                    policy: setup.setup.noShow, client: loaded.client, appointments: history,
                    marking: loaded.appointment
                ),
                now: now(), calendar: business.calendar
            )
            visit = loaded
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("noShowMark.error.load"))
        }
    }

    func confirm() {
        Task { await confirmAsync() }
    }

    func confirmAsync() async {
        guard !isWorking, canMark, let visit else { return }
        isWorking = true
        defer { isWorking = false }
        let moment = now()
        let forgive = !countsAgainstClient
        do {
            let changed = try await appointments.markNoShow(id: appointmentID, forgive: forgive, now: moment)
            self.visit = VisitContext(appointment: changed, client: visit.client)
        } catch {
            actionErrorMessage = String(interface: LocalizedStringResource("noShowMark.error.save"))
            return
        }
        actionErrorMessage = nil
        var outcome: MessageService.Outcome?
        if sendsNote {
            outcome = await messages.send(
                text: noteText(for: visit), to: visit.client.id, phoneE164: visit.client.phoneE164,
                template: AppointmentMessageKind.noShow.logTemplate, preferred: business.preferredChannel, now: moment
            )
        }
        done = Done(forgiven: forgive, message: outcome)
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    /// The note as it will open, shown on the toggle so she reads it before saving.
    var notePreview: String? {
        visit.map(noteText(for:))
    }

    private func noteText(for visit: VisitContext) -> String {
        let values = AppointmentMessageComposer.values(client: visit.client, appointment: visit.appointment, link: nil)
        return AppointmentMessageComposer.text(
            for: .noShow, values: values, localization: business.localization, formatters: business.messageFormatters
        )
    }
}
