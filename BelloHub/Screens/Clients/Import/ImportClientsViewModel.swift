//
//  ImportClientsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The state and actions of the whole client import (4.6): the sources, the column mapping of a spreadsheet, the choice
/// of who to bring over and the result. One ViewModel for the flow, so going back and forward keeps what she did
/// (docs/04-ARCHITECTURE.md section 5). Every client reaches the vault through `ClientRegistering.importClients`, the
/// registration gate of D42; nothing here saves a client any other way.
@MainActor
@Observable
final class ImportClientsViewModel {
    private(set) var step: ImportStep = .sources
    private(set) var source: ImportSource?
    /// True while a file is being read or the import is being saved. One at a time: a second request is ignored.
    private(set) var isWorking = false
    private(set) var problem: ImportProblem?

    // Spreadsheet
    private(set) var fileName: String?
    private(set) var table: ImportTable?
    private(set) var mapping = ImportColumnMapping()

    // Choose
    /// The rows that can become clients, in the order they are listed and imported.
    private(set) var readyEntries: [ImportEntry] = []
    /// The rows that cannot, with the reason. Never selectable.
    private(set) var skippedEntries: [ImportEntry] = []
    private(set) var selection: Set<String> = []

    // Result
    private(set) var result: ClientImportResult?

    /// Presented by the view: the system's file importer, and the paywall for the rows the free registrations left out.
    var isFileImporterPresented = false
    var isPaywallPresented = false

    let contacts: any ContactsImporting
    let files: any ImportFileReading
    private let registrar: any ClientRegistering
    private let settings: any SettingsOpening
    private let region: RegionPreset
    private let regions: RegionCatalog
    private let phones: PhoneNormalizer
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(
        registrar: any ClientRegistering,
        region: RegionPreset,
        regions: RegionCatalog,
        contacts: any ContactsImporting = SystemContactsImporter(),
        files: any ImportFileReading = SystemImportFileReader(),
        settings: any SettingsOpening = SystemSettingsOpener(),
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.registrar = registrar
        self.region = region
        self.regions = regions
        self.phones = PhoneNormalizer(catalog: regions)
        self.contacts = contacts
        self.files = files
        self.settings = settings
        self.now = now
        self.makeID = makeID
    }

    // MARK: - Counter

    /// The free-registration counter, read from the gate so every screen shows the same number.
    var usage: RegistrationUsage { registrar.usage }

    /// How much of the chosen batch the free registrations cover.
    var fit: ImportBatchFit { ImportBatchFit(selected: selection.count, usage: usage) }

    /// Reads the counter when the screen opens.
    func start() async {
        await registrar.refreshUsage()
    }

    // MARK: - Sources

    /// Phone contacts: opens the system picker and lists what she chose.
    func chooseContacts() {
        Task { await pickContacts() }
    }

    func pickContacts() async {
        guard !isWorking else { return }
        problem = nil
        guard contacts.access == .available else {
            problem = .contactsRestricted
            return
        }
        let candidates = await contacts.pickContacts()
        guard !candidates.isEmpty else { return }
        source = .contacts
        let entries = makeMapper().entries(from: candidates, makeID: makeID)
        showChoices(ImportClientMapper.sortedByName(entries))
    }

    /// Spreadsheet: shows the file importer (or, in a UI-test launch, goes straight to the preset file).
    func chooseSpreadsheet() {
        problem = nil
        if let preset = files.presetFile {
            Task { await openSpreadsheet(at: preset) }
        } else {
            isFileImporterPresented = true
        }
    }

    /// The answer of the system file importer. Cancelling is not an error.
    func fileImporterFinished(_ outcome: Result<[URL], Error>) {
        switch outcome {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await openSpreadsheet(at: url) }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled { problem = .fileUnreadable }
        }
    }

    func openSpreadsheet(at url: URL) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        problem = nil
        let text: String
        do {
            text = try await files.readText(at: url)
        } catch {
            problem = .fileUnreadable
            return
        }
        // Parsing a big file is the one slow thing here, so it runs off the main actor.
        let parsed = await Task.detached(priority: .userInitiated) {
            ImportTable(document: CSVParser.parse(text))
        }.value
        guard !parsed.isEmpty else {
            problem = .fileEmpty
            return
        }
        source = .spreadsheet
        fileName = url.lastPathComponent
        table = parsed
        mapping = ImportColumnMapper.detect(in: parsed)
        step = .mapping
    }

    func openSettings() {
        settings.openSettings()
    }

    // MARK: - Mapping

    func setColumn(_ role: ImportColumnRole, to column: Int?) {
        mapping[role] = column
    }

    /// She corrects the guess about the first row: titles, or the first client. The columns are guessed again.
    func setFirstRowIsHeader(_ isHeader: Bool) {
        guard let table, table.hasHeader != isHeader else { return }
        let changed = table.settingHeader(isHeader)
        self.table = changed
        mapping = ImportColumnMapper.detect(in: changed)
    }

    /// The first rows as they will be imported with the current mapping, for the preview under the pickers.
    var mappingPreview: [ImportEntry] {
        guard let table, mapping.hasName else { return [] }
        let candidates = ImportColumnMapper.candidates(from: table, mapping: mapping, limit: 3)
        return makeMapper().entries(from: candidates, makeID: makeID)
    }

    var canContinueFromMapping: Bool { mapping.hasName && !(table?.isEmpty ?? true) }

    func confirmMappingAndContinue() {
        Task { await confirmMapping() }
    }

    func confirmMapping() async {
        guard step == .mapping, !isWorking, let table, mapping.hasName else { return }
        isWorking = true
        defer { isWorking = false }
        let mapper = makeMapper()
        let mapping = mapping
        let makeID = makeID
        let entries = await Task.detached(priority: .userInitiated) {
            mapper.entries(from: ImportColumnMapper.candidates(from: table, mapping: mapping), makeID: makeID)
        }.value
        showChoices(entries)
    }

    // MARK: - Choosing

    var allSelected: Bool { !readyEntries.isEmpty && selection.count == readyEntries.count }
    var canImport: Bool { !selection.isEmpty && !isWorking }

    func isSelected(_ id: String) -> Bool { selection.contains(id) }

    func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    /// "Select all", or "Clear" when everything is already selected.
    func toggleAll() {
        selection = allSelected ? [] : Set(readyEntries.map(\.id))
    }

    /// The chosen clients, in list order. The gate takes them in this order, so with fewer free slots than clients the
    /// ones at the top of the list are the ones registered.
    var selectedClients: [Client] {
        readyEntries.compactMap { selection.contains($0.id) ? $0.client : nil }
    }

    func back() {
        problem = nil
        switch step {
        case .choose: step = source == .spreadsheet ? .mapping : .sources
        case .mapping: step = .sources
        case .sources, .result: break
        }
    }

    // MARK: - Importing

    func importSelectedClients() {
        Task { await importSelected() }
    }

    func importSelected() async {
        guard step == .choose, canImport else { return }
        isWorking = true
        defer { isWorking = false }
        problem = nil
        do {
            var outcome = try await registrar.importClients(selectedClients)
            // The gate cannot know which rows were unreadable: they never reached it.
            outcome.malformed = skippedEntries.count
            result = outcome
            step = .result
        } catch {
            problem = .importFailed
        }
    }

    func showPaywall() {
        isPaywallPresented = true
    }

    // MARK: - Display

    /// The phone of a ready entry as people write it (`+55 11 98123-4410`), kept left-to-right inside Arabic text.
    func phoneText(for entry: ImportEntry) -> String? {
        guard let phone = entry.client?.phoneE164 else { return nil }
        return BidiIsolate.wrapLeftToRight(PhoneFormatter(catalog: regions).international(phone))
    }

    // MARK: - Private

    private func makeMapper() -> ImportClientMapper {
        ImportClientMapper(region: region, phones: phones, now: now())
    }

    private func showChoices(_ entries: [ImportEntry]) {
        readyEntries = entries.filter(\.isReady)
        skippedEntries = entries.filter { !$0.isReady }
        selection = Set(readyEntries.map(\.id))
        result = nil
        step = .choose
    }
}
