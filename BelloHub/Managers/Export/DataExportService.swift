//
//  DataExportService.swift
//  BelloHub
//

import Foundation
import Observation

/// Export all my data (7.8, D18): reads the vault, builds the ZIP on the device and writes it to a protected temp
/// file for the share sheet. The file is removed when the screen is done with it. Nothing goes to a server.
@MainActor
@Observable
final class DataExportService {
    private(set) var isPreparing = false
    private(set) var errorMessage: String?
    /// The archive ready to share, until `discard()`.
    private(set) var file: ProtectedTemporaryFile?

    private let vault: VaultService
    private let now: @Sendable () -> Date

    init(vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }) {
        self.vault = vault
        self.now = now
    }

    /// Reads everything and builds the archive. Returns the file, or nil with `errorMessage` set.
    @discardableResult
    func prepare(
        contents: ExportContents, locale: Locale, profile: ProfessionalProfile?
    ) async -> ProtectedTemporaryFile? {
        guard !isPreparing else { return file }
        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }
        discard()
        do {
            let snapshot = try await Self.snapshot(from: vault, includesPhotos: contents.includesPhotos)
            let builder = ExportBundleBuilder(
                formatters: Formatters(
                    locale: locale,
                    timeZone: profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current,
                    currencyCode: profile?.currencyCode ?? "EUR",
                    firstWeekday: profile?.firstWeekday
                ),
                locale: locale, now: now()
            )
            let pdf = SummaryPDFRenderer().render(builder.summary(snapshot))
            let archive = ZipWriter(now: now()).archive(builder.entries(snapshot, pdf: pdf, contents: contents))
            let written = try ProtectedTemporaryFile.write(archive, named: builder.archiveName())
            file = written
            return written
        } catch {
            errorMessage = String(
                localized: "export.error",
                defaultValue: "We could not prepare the export. Check that your iPhone has space and try again."
            )
            return nil
        }
    }

    /// Deletes the temp file (the screen leaves, or the share sheet closed).
    func discard() {
        file?.remove()
        file = nil
    }

    // MARK: - Reading

    static func snapshot(from vault: VaultService, includesPhotos: Bool) async throws -> ExportSnapshot {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        var snapshot = ExportSnapshot()
        snapshot.profile = try await repository.profile()
        snapshot.clients = try await repository.allClients()
        snapshot.tags = try await repository.tags()
        snapshot.services = try await repository.services()
        snapshot.appointments = try await repository.loadAppointments(in: DateInterval(
            start: .distantPast, end: .distantFuture
        ))
        for client in snapshot.clients {
            snapshot.records += try await repository.records(for: client.id)
            guard includesPhotos else { continue }
            for photo in try await repository.photos(for: client.id) {
                snapshot.photos.append((photo, try await repository.photoData(id: photo.id)))
            }
        }
        return snapshot
    }
}
