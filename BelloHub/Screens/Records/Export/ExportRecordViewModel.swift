//
//  ExportRecordViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 4.10 ExportRecord: what goes into the PDF (a copy for the client or for a health professional),
/// building it through `RecordExporting`, and getting rid of the file once it was shared. The record is read from the
/// vault, cut down by `RecordExportSelector` and laid out by `RecordExportDocumentBuilder`; nothing is uploaded.
@MainActor
@Observable
final class ExportRecordViewModel {
    enum Phase: Equatable {
        case loading
        case missing
        case failed(String)
        case form
        /// The PDF exists and waits to be shared.
        case ready(ExportedFile)
        /// It was shared and the file is gone.
        case shared
    }

    /// What the card at the top says about the client: how many treatments and when she signed.
    struct Summary: Equatable {
        var treatmentCount: Int
        var consentSignedAt: Date?
    }

    let clientID: UUID
    private(set) var phase: Phase = .loading
    private(set) var client: Client?
    private(set) var summary = Summary(treatmentCount: 0, consentSignedAt: nil)
    private(set) var photoCount = 0
    private(set) var business: AgendaBusinessContext
    private(set) var isWorking = false
    private(set) var exportErrorMessage: String?
    var options = ExportOptions()

    private let vault: VaultService
    private let profile: ProfileService
    private let exporter: any RecordExporting
    private let now: @Sendable () -> Date
    private let resolve: (LocalizedStringResource) -> String
    private let displayLocale: Locale

    init(
        clientID: UUID, vault: VaultService, profile: ProfileService, exporter: any RecordExporting,
        locale: Locale = .current, now: @escaping @Sendable () -> Date = { Date() },
        resolve: @escaping (LocalizedStringResource) -> String = { String(interface: $0) }
    ) {
        self.clientID = clientID
        self.vault = vault
        self.profile = profile
        self.exporter = exporter
        self.displayLocale = locale
        self.now = now
        self.resolve = resolve
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    var canExport: Bool { phase == .form && !isWorking }

    /// Picking the client's copy puts the internal-notes switch off for good: the rule is in `ExportOptions`.
    func setAudience(_ audience: ExportAudience) {
        options.audience = audience
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        guard let repository = vault.repository else {
            phase = .failed(String(interface: LocalizedStringResource("exportRecord.error.load")))
            return
        }
        do {
            guard let loaded = try await repository.client(id: clientID) else {
                phase = .missing
                return
            }
            client = loaded
            summary = Summary(
                treatmentCount: try await repository.records(for: clientID).count,
                consentSignedAt: try await repository.consents(for: clientID).filter(\.isSigned)
                    .map(\.effectiveDate).max()
            )
            photoCount = try await repository.photos(for: clientID).count
            if phase == .loading { phase = .form } else if case .failed = phase { phase = .form }
        } catch {
            phase = .failed(String(interface: LocalizedStringResource("exportRecord.error.load")))
        }
    }

    func export() {
        Task { await exportAsync() }
    }

    func exportAsync() async {
        guard canExport, let client, let repository = vault.repository else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let records = try await repository.records(for: clientID)
            var corrections: [RecordCorrection] = []
            for record in records { corrections += try await repository.corrections(for: record.id) }
            let source = RecordExportSource(
                client: client, records: records, corrections: corrections,
                incidents: try await repository.incidents(for: clientID),
                photos: try await repository.photos(for: clientID),
                consents: try await repository.consents(for: clientID)
            )
            let content = RecordExportSelector.content(
                from: source, options: options, now: now(), calendar: business.calendar
            )
            var images: [UUID: Data] = [:]
            for photo in content.photos { images[photo.id] = try await repository.photoData(id: photo.id).image }
            let builder = RecordExportDocumentBuilder(
                resolve: resolve, formatters: business.formatters(displayLocale: displayLocale),
                professionalName: profile.profile?.displayName ?? "", now: now()
            )
            let file = try await exporter.export(builder.document(for: content, photoData: images))
            exportErrorMessage = nil
            phase = .ready(file)
        } catch {
            exportErrorMessage = String(interface: LocalizedStringResource("exportRecord.error.export"))
        }
    }

    /// The share sheet closed. A finished share deletes the file; a cancelled one keeps it so she can try again.
    func shareFinished(completed: Bool) {
        guard case .ready(let file) = phase, completed else { return }
        exporter.discard(file)
        phase = .shared
    }

    /// The screen is going away: the file never outlives it.
    func discardFile() {
        guard case .ready(let file) = phase else { return }
        exporter.discard(file)
        phase = .form
    }

    func dismissExportError() {
        exportErrorMessage = nil
    }
}
