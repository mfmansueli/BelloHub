//
//  ImportClientsViewModelSpreadsheetTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The spreadsheet path of the import ViewModel: reading the file, mapping the columns, validating the rows.
@MainActor
@Suite("ImportClientsViewModel, spreadsheets")
struct ImportClientsViewModelSpreadsheetTests {
    private let fileURL = ImportViewModelRig.fileURL
    private let sheet = ImportViewModelRig.sheet

    @Test("A spreadsheet is read, its columns are guessed and the mapping step opens")
    func opensTheMapping() async throws {
        let rig = try ImportViewModelRig(text: sheet)

        await rig.model.openSpreadsheet(at: fileURL)

        let model = rig.model
        #expect(model.step == .mapping && model.source == .spreadsheet)
        #expect(model.fileName == "clients.csv")
        #expect(model.table?.rows.count == 4)
        #expect(model.mapping == ImportColumnMapping(name: 0, lastName: nil, phone: 1, email: nil))
        #expect(model.canContinueFromMapping)
        #expect(rig.files.readURLs == [fileURL])
    }

    @Test("Confirming the mapping validates every row: good ones are listed, bad ones say why")
    func rowsAreValidated() async throws {
        let rig = try ImportViewModelRig(text: sheet)
        await rig.model.openSpreadsheet(at: fileURL)

        await rig.model.confirmMapping()

        let model = rig.model
        #expect(model.step == .choose)
        #expect(model.readyEntries.map(\.displayName) == ["Ana", "Carla"], "a spreadsheet keeps the order of the file")
        #expect(model.skippedEntries.map(\.issue) == [.invalidPhone, .nameMissing])
        #expect(model.skippedEntries.map(\.rowNumber) == [3, 4], "row numbers are those of the file")
        #expect(model.selection.count == 2)
    }

    @Test("Changing a column changes what is imported, and a file with no name column cannot continue")
    func mappingCanBeChanged() async throws {
        let rig = try ImportViewModelRig(text: "A;B\nAna;Bia\nCarla;Dani")
        await rig.model.openSpreadsheet(at: fileURL)
        let model = rig.model

        model.setColumn(.name, to: 1)
        await model.confirmMapping()
        #expect(model.readyEntries.map(\.displayName) == ["Bia", "Dani"])

        model.back()
        model.setColumn(.name, to: nil)
        #expect(!model.canContinueFromMapping)
        await model.confirmMapping()
        #expect(model.step == .mapping, "no name column, no continue")
    }

    @Test("She can say the first row is not a header, and the columns are guessed again")
    func headerCorrection() async throws {
        let rig = try ImportViewModelRig(text: "Pessoa;Contato\nAna;(11) 98765-4321")
        await rig.model.openSpreadsheet(at: fileURL)
        #expect(rig.model.table?.hasHeader == true)

        rig.model.setFirstRowIsHeader(false)

        #expect(rig.model.table?.hasHeader == false)
        #expect(rig.model.table?.rows.count == 2)
    }

    @Test("The preview shows the first rows with the current choices")
    func preview() async throws {
        let rig = try ImportViewModelRig(text: sheet)
        await rig.model.openSpreadsheet(at: fileURL)

        #expect(rig.model.mappingPreview.map(\.displayName) == ["Ana", "Bia", ""])
        #expect(rig.model.mappingPreview.map(\.issue) == [nil, .invalidPhone, .nameMissing])

        rig.model.setColumn(.name, to: nil)
        #expect(rig.model.mappingPreview.isEmpty)
    }

    @Test("Back moves one step: choose, mapping, sources")
    func backNavigation() async throws {
        let rig = try ImportViewModelRig(text: sheet)
        await rig.model.openSpreadsheet(at: fileURL)
        await rig.model.confirmMapping()

        rig.model.back()
        #expect(rig.model.step == .mapping)
        rig.model.back()
        #expect(rig.model.step == .sources)

        let contacts = try ImportViewModelRig(contacts: [ImportViewModelRig.makeContact("Ana")])
        await contacts.model.pickContacts()
        contacts.model.back()
        #expect(contacts.model.step == .sources, "contacts have no mapping step")
    }

    // MARK: - Files that do not work

    @Test("A file that cannot be read says so and stays on the sources",
          arguments: [ImportFileError.unreadable, .tooLarge])
    func unreadableFile(error: ImportFileError) async throws {
        let rig = try ImportViewModelRig()
        rig.files.error = error

        await rig.model.openSpreadsheet(at: fileURL)

        #expect(rig.model.problem == .fileUnreadable)
        #expect(rig.model.step == .sources)
        #expect(!rig.model.isWorking)
    }

    @Test("A file with no rows says so", arguments: ["", "   \n\n", "Nome;Telefone", "Nome;Telefone\n;\n;\n"])
    func emptyFile(text: String) async throws {
        let rig = try ImportViewModelRig(text: text)

        await rig.model.openSpreadsheet(at: fileURL)

        #expect(rig.model.problem == .fileEmpty)
        #expect(rig.model.step == .sources)
    }

    // MARK: - The file importer

    @Test("Without a preset file the file importer is shown")
    func fileImporterIsShown() throws {
        let rig = try ImportViewModelRig(text: sheet)

        rig.model.chooseSpreadsheet()

        #expect(rig.model.isFileImporterPresented)
        #expect(rig.files.readURLs.isEmpty)
    }

    @Test("With a preset file (UI tests) the file importer is skipped and the file is read")
    func presetFileSkipsTheImporter() async throws {
        let preset = try #require(URL(string: "bellohub-fixture:clients.csv"))
        let rig = try ImportViewModelRig(text: sheet, presetFile: preset)

        rig.model.chooseSpreadsheet()
        await Wait.untilMain { rig.model.step == .mapping }

        #expect(!rig.model.isFileImporterPresented)
        #expect(rig.files.readURLs == [preset])
        #expect(rig.model.fileName == "clients.csv")
    }

    @Test("The file importer's answer opens the file; a cancel is not an error; a failure is")
    func fileImporterAnswers() async throws {
        let rig = try ImportViewModelRig(text: sheet)

        rig.model.fileImporterFinished(.failure(CocoaError(.userCancelled)))
        #expect(rig.model.problem == nil)

        rig.model.fileImporterFinished(.failure(CocoaError(.fileReadNoPermission)))
        #expect(rig.model.problem == .fileUnreadable)

        rig.model.fileImporterFinished(.success([fileURL]))
        await Wait.untilMain { rig.model.step == .mapping }
        #expect(rig.model.problem == nil)
    }

    // MARK: - Size

    @Test("2,000 rows go from file to a selectable list (generous bound: the suite runs in parallel)")
    func twoThousandRows() async throws {
        var lines = ["Nome;Telefone;E-mail"]
        for index in 1...2_000 {
            let digits = String(format: "%04d", index)
            lines.append("Cliente \(index);(11) 9\(digits)-\(digits);c\(index)@example.com")
        }
        let rig = try ImportViewModelRig(text: lines.joined(separator: "\r\n"))
        let clock = ContinuousClock()
        let started = clock.now

        await rig.model.openSpreadsheet(at: fileURL)
        await rig.model.confirmMapping()
        let elapsed = clock.now - started

        #expect(rig.model.readyEntries.count == 2_000)
        #expect(rig.model.selectedClients.count == 2_000)
        #expect(rig.model.skippedEntries.isEmpty)
        #expect(elapsed < .seconds(20), "took \(elapsed)")
    }
}
