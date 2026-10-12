//
//  ClientProfileViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of one client's record (4.1): it watches the vault and rebuilds the snapshot
/// (`ClientProfileBuilder`) and the visit timeline (`ClientTimelineBuilder`) when anything changes, so an edit, a new
/// appointment or a saved visit shows at once. Its own actions are the call and the record section she is looking at.
@MainActor
@Observable
final class ClientProfileViewModel {
    let clientID: UUID
    private(set) var snapshot: ClientProfileSnapshot?
    /// Her visits, pending records and bookings that did not happen, newest first.
    private(set) var timeline: ClientTimeline = .empty
    /// The part of the record on screen; History opens first.
    var section: ClientRecordSection = .history
    private(set) var isLoading = true
    /// She was merged into another profile or deleted while this screen was open.
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    /// The phone could not place the call (an iPhone without a SIM, the simulator): the screen says so.
    private(set) var callFailed = false

    private let vault: VaultService
    private let profile: ProfileService
    private let phone: any PhoneLaunching
    private let now: @Sendable () -> Date
    private let listeners = TaskBag()
    private var isReloading = false
    private var needsReload = false
    /// Decrypted thumbnails, kept only while the record is open. A thumbnail is small (about 20 KB), so even a long
    /// record holds a few megabytes at most; full images are never loaded here.
    private var thumbnails: [UUID: Data] = [:]
    /// Full images for a comparison, only the last few (`PhotoMemoryCache`).
    private var fullImages = PhotoMemoryCache()

    init(
        clientID: UUID,
        vault: VaultService,
        profile: ProfileService,
        phone: any PhoneLaunching = PhoneLauncher(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.clientID = clientID
        self.vault = vault
        self.profile = profile
        self.phone = phone
        self.now = now
    }

    // MARK: - Derived

    var tagsByID: [UUID: Tag] {
        Dictionary(profile.tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var chips: [ClientProfileChip] {
        snapshot.map { ClientProfileChip.chips(for: $0.client, habits: $0.habits, tagsByID: tagsByID) } ?? []
    }

    /// There is a number to call.
    var canCall: Bool {
        snapshot?.client.phoneE164.flatMap(PhoneLauncher.telURL(forE164:)) != nil
    }

    /// There is a number to open WhatsApp with.
    var canMessage: Bool {
        snapshot?.client.phoneE164 != nil
    }

    /// Opens the visit flow for a visit with no appointment (a walk-in, an old visit she is writing now).
    var newVisitRequest: TreatmentFlowRequest {
        TreatmentFlowRequest(clientID: clientID)
    }

    /// Opens the visit flow for a completed appointment that has no record yet. If a record appeared meanwhile, the
    /// flow opens that one (`RecordForAppointment`), so this never makes a second record for the appointment.
    func pendingRecordRequest(for appointment: Appointment) -> TreatmentFlowRequest {
        TreatmentFlowRequest(clientID: clientID, appointmentID: appointment.id, serviceID: appointment.serviceID)
    }

    /// Continues a draft where she left it.
    func continueRequest(for visit: VisitSummary) -> TreatmentFlowRequest {
        TreatmentFlowRequest(clientID: clientID, appointmentID: visit.record.appointmentID,
                             serviceID: visit.record.serviceID, recordID: visit.record.id)
    }

    /// A photo's full image, for a comparison. Only the last few stay in memory.
    func fullPhoto(for photo: Photo) async -> PhotoData? {
        if let cached = fullImages.photo(photo.id) { return cached }
        guard let repository = vault.repository, let data = try? await repository.photoData(id: photo.id) else {
            return nil
        }
        fullImages.store(data, for: photo.id)
        return data
    }

    /// The thumbnail of a photo, decrypted on first use and kept while the record is open.
    func thumbnail(for photo: Photo) async -> Data? {
        if let cached = thumbnails[photo.id] { return cached }
        guard let repository = vault.repository,
              let data = try? await repository.photoThumbnail(id: photo.id) else { return nil }
        thumbnails[photo.id] = data
        return data
    }

    // MARK: - Listening

    /// Starts watching the vault. Safe to call again: a running watch is kept.
    func startListening() {
        guard listeners.isEmpty else { return }
        guard let repository = vault.repository else { return fail() }
        listeners.add([
            Task { [weak self] in
                await self?.reload()
                for await _ in repository.clients() {
                    guard let self, !Task.isCancelled else { return }
                    await self.reload()
                }
            },
            Task { [weak self] in
                for await _ in repository.appointments(in: DateInterval(start: .distantPast, end: .distantFuture)) {
                    guard let self, !Task.isCancelled else { return }
                    await self.reload()
                }
            }
        ])
    }

    func stopListening() {
        listeners.cancelAll()
        snapshot = nil
        timeline = .empty
        thumbnails = [:]
        fullImages = PhotoMemoryCache()
        isLoading = true
        isMissing = false
        errorMessage = nil
        callFailed = false
    }

    // MARK: - Actions

    /// Fire-and-forget entry point for the retry button (CLAUDE.md section 2).
    func refresh() {
        Task { await refreshAsync() }
    }

    /// For `.refreshable`.
    func refreshAsync() async {
        await reload()
    }

    func call() {
        Task { await callAsync() }
    }

    func callAsync() async {
        guard let number = snapshot?.client.phoneE164 else { return }
        callFailed = !(await phone.call(number))
    }

    func dismissCallFailure() {
        callFailed = false
    }

    // MARK: - Private

    /// One reload at a time; a change that arrives while one runs asks for exactly one more, so the screen always ends
    /// on the latest state without queueing a reload per emission.
    private func reload() async {
        if isReloading {
            needsReload = true
            return
        }
        isReloading = true
        defer { isReloading = false }
        repeat {
            needsReload = false
            await performReload()
        } while needsReload
    }

    private func performReload() async {
        guard let repository = vault.repository else { return fail() }
        do {
            guard let client = try await repository.client(id: clientID) else {
                snapshot = nil
                isMissing = true
                isLoading = false
                return
            }
            let appointments = try await repository.appointments(for: clientID)
            let input = ClientProfileBuilder.Input(
                client: client,
                appointments: appointments,
                plans: try await repository.sessionPlans(for: clientID),
                forms: try await repository.healthForms(for: clientID),
                consents: try await repository.consents(for: clientID)
            )
            let moment = now()
            snapshot = ClientProfileBuilder.make(input, now: moment, calendar: calendar)
            timeline = ClientTimelineBuilder.make(
                try await timelineInput(repository, appointments: appointments), now: moment, list: formatters.list
            )
            isMissing = false
            errorMessage = nil
            isLoading = false
        } catch {
            fail()
        }
    }

    /// Everything of hers the timeline groups: records with their corrections, photos (metadata only) and incidents.
    private func timelineInput(
        _ repository: any ClientRecordRepository, appointments: [Appointment]
    ) async throws -> ClientTimelineBuilder.Input {
        let records = try await repository.records(for: clientID)
        var corrections: [RecordCorrection] = []
        for record in records where !record.isDraft {
            corrections += try await repository.corrections(for: record.id)
        }
        return ClientTimelineBuilder.Input(
            records: records, corrections: corrections, appointments: appointments,
            photos: try await repository.photos(for: clientID), incidents: try await repository.incidents(for: clientID)
        )
    }

    private func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("clientProfile.error.message"))
    }

    /// For the timeline's summaries, in the language of the interface.
    private var formatters: Formatters {
        Formatters(locale: InterfaceLocale.current, timeZone: calendar.timeZone,
                   currencyCode: profile.profile?.currencyCode ?? "USD")
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return calendar
    }
}
