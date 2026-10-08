//
//  InMemoryClientRecordRepository.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// The vault in memory: SwiftUI previews, the Design Catalog and UI-test launches (`-uiSeed`), where a real store
/// would be slow or shared. DEBUG only, so a Release build can never run without the real vault. It must behave
/// exactly like `SwiftDataClientRecordRepository`: the contract tests run the same cases against both.
actor InMemoryClientRecordRepository: ClientRecordRepository {
    private var clientsByID: [UUID: Client] = [:]
    private var appointmentsByID: [UUID: Appointment] = [:]
    private var servicesByID: [UUID: Service] = [:]
    private var recordsByID: [UUID: TreatmentRecord] = [:]
    private var correctionsByID: [UUID: RecordCorrection] = [:]
    private var incidentsByID: [UUID: Incident] = [:]
    private var photosByID: [UUID: Photo] = [:]
    private var photoDataByID: [UUID: PhotoData] = [:]
    private var healthFormsByID: [UUID: HealthForm] = [:]
    private var consentsByID: [UUID: Consent] = [:]
    private var plansByID: [UUID: SessionPlan] = [:]
    private var ledger: [UUID: RegistrationLedgerEntry] = [:]
    private let clock: @Sendable () -> Date
    private let changes = VaultChangeBroadcaster()

    init(clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
    }

    // MARK: - ClientRepository

    nonisolated func clients() -> AsyncStream<[Client]> {
        changes.stream { [self] in await allClients() }
    }

    func allClients() -> [Client] {
        clientsByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func client(id: UUID) -> Client? {
        clientsByID[id]
    }

    @discardableResult
    func save(_ client: Client) -> Bool {
        var stored = client
        stored.updatedAt = clock()
        clientsByID[client.id] = stored
        let isNew = ledger[client.id] == nil
        if isNew { ledger[client.id] = RegistrationLedgerEntry(clientID: client.id, registeredAt: clock()) }
        changes.notify()
        return isNew
    }

    func deleteClient(id: UUID) {
        let recordIDs = recordsByID.values.filter { $0.clientID == id }.map(\.id)
        correctionsByID = correctionsByID.filter { !recordIDs.contains($0.value.recordID) }
        recordsByID = recordsByID.filter { $0.value.clientID != id }
        appointmentsByID = appointmentsByID.filter { $0.value.clientID != id }
        incidentsByID = incidentsByID.filter { $0.value.clientID != id }
        let photoIDs = photosByID.values.filter { $0.clientID == id }.map(\.id)
        photoIDs.forEach { photoDataByID[$0] = nil }
        photosByID = photosByID.filter { $0.value.clientID != id }
        healthFormsByID = healthFormsByID.filter { $0.value.clientID != id }
        consentsByID = consentsByID.filter { $0.value.clientID != id }
        plansByID = plansByID.filter { $0.value.clientID != id }
        clientsByID[id] = nil
        // The registration-ledger entry stays (D42).
        changes.notify()
    }

    func registrationLedger() -> [RegistrationLedgerEntry] {
        ledger.values.sorted { ($0.registeredAt, $0.clientID.uuidString) < ($1.registeredAt, $1.clientID.uuidString) }
    }

    func healthForms(for clientID: UUID) -> [HealthForm] {
        healthFormsByID.values.filter { $0.clientID == clientID }
            .sorted { ($0.signedAt ?? .distantPast) > ($1.signedAt ?? .distantPast) }
    }

    func save(_ form: HealthForm) {
        healthFormsByID[form.id] = form
        changes.notify()
    }

    func importHealthForm(_ form: HealthForm) -> Bool {
        if let itemID = form.importedFromItemID,
           healthFormsByID.values.contains(where: { $0.importedFromItemID == itemID }) {
            return false
        }
        healthFormsByID[form.id] = form
        changes.notify()
        return true
    }

    func consents(for clientID: UUID) -> [Consent] {
        consentsByID.values.filter { $0.clientID == clientID }.sorted { $0.signedAt > $1.signedAt }
    }

    func save(_ consent: Consent) {
        consentsByID[consent.id] = consent
        changes.notify()
    }

    func sessionPlans(for clientID: UUID) -> [SessionPlan] {
        plansByID.values.filter { $0.clientID == clientID }.sorted { $0.startDate < $1.startDate }
    }

    func save(_ plan: SessionPlan) {
        plansByID[plan.id] = plan
        changes.notify()
    }

    // MARK: - AgendaRepository

    nonisolated func appointments(in range: DateInterval) -> AsyncStream<[Appointment]> {
        changes.stream { [self] in await loadAppointments(in: range) }
    }

    func loadAppointments(in range: DateInterval) -> [Appointment] {
        appointmentsByID.values.filter { $0.startsAt < range.end && $0.endsAt > range.start }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func appointments(for clientID: UUID) -> [Appointment] {
        appointmentsByID.values.filter { $0.clientID == clientID }.sorted { $0.startsAt < $1.startsAt }
    }

    func appointment(id: UUID) -> Appointment? {
        appointmentsByID[id]
    }

    func save(_ appointment: Appointment) {
        var stored = appointment
        stored.updatedAt = clock()
        appointmentsByID[appointment.id] = stored
        changes.notify()
    }

    func deleteAppointment(id: UUID) {
        appointmentsByID[id] = nil
        changes.notify()
    }

    func services() -> [Service] {
        servicesByID.values.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ service: Service) {
        servicesByID[service.id] = service
        changes.notify()
    }

    func deleteService(id: UUID) {
        servicesByID[id] = nil
        changes.notify()
    }

    // MARK: - TreatmentRepository

    func records(for clientID: UUID) -> [TreatmentRecord] {
        recordsByID.values.filter { $0.clientID == clientID }.sorted { $0.createdAt > $1.createdAt }
    }

    func record(id: UUID) -> TreatmentRecord? {
        recordsByID[id]
    }

    func save(_ record: TreatmentRecord) throws {
        var stored = record
        if let existing = recordsByID[record.id] {
            guard !RecordLockPolicy.isLocked(lockedAt: existing.lockedAt, now: clock()) else {
                throw VaultRepositoryError.recordLocked
            }
            stored.lockedAt = existing.lockedAt
            stored.createdAt = existing.createdAt
        }
        recordsByID[record.id] = stored
        changes.notify()
    }

    func addCorrection(_ correction: RecordCorrection) throws {
        guard let record = recordsByID[correction.recordID] else { throw VaultRepositoryError.notFound }
        guard RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: clock()) else {
            throw VaultRepositoryError.recordNotLocked
        }
        guard correctionsByID[correction.id] == nil else { return }
        correctionsByID[correction.id] = correction
        changes.notify()
    }

    func corrections(for recordID: UUID) -> [RecordCorrection] {
        correctionsByID.values.filter { $0.recordID == recordID }.sorted { $0.createdAt < $1.createdAt }
    }

    func incidents(for clientID: UUID) -> [Incident] {
        incidentsByID.values.filter { $0.clientID == clientID }.sorted { $0.occurredAt > $1.occurredAt }
    }

    func save(_ incident: Incident) throws {
        var stored = incident
        if let existing = incidentsByID[incident.id] {
            guard !RecordLockPolicy.isLocked(lockedAt: existing.lockedAt, now: clock()) else {
                throw VaultRepositoryError.recordLocked
            }
            stored.lockedAt = existing.lockedAt
        }
        incidentsByID[incident.id] = stored
        changes.notify()
    }

    func photos(for clientID: UUID) -> [Photo] {
        photosByID.values.filter { $0.clientID == clientID }.sorted { $0.takenAt < $1.takenAt }
    }

    func save(_ photo: Photo, data: PhotoData) {
        photosByID[photo.id] = photo
        photoDataByID[photo.id] = data
        changes.notify()
    }

    func photoData(id: UUID) throws -> PhotoData {
        guard let data = photoDataByID[id] else { throw VaultRepositoryError.notFound }
        return data
    }

    func deletePhoto(id: UUID) {
        photosByID[id] = nil
        photoDataByID[id] = nil
        changes.notify()
    }
}
#endif
