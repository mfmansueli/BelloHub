//
//  ImportDependencies.swift
//  BelloHub
//

/// What the import needs from the system, built in one place: the real ones, or (in a UI-test launch) the fixtures a
/// launch argument names. The ViewModel takes the three separately, so a unit test passes its own fakes.
@MainActor
struct ImportDependencies {
    let contacts: any ContactsImporting
    let files: any ImportFileReading
    let settings: any SettingsOpening

    static func make(options: LaunchOptions = .current) -> ImportDependencies {
        #if DEBUG
        let contacts: any ContactsImporting = options.uiContacts.map { FixtureContactsImporter.fixture(named: $0) }
            ?? SystemContactsImporter()
        let files: any ImportFileReading = options.uiSpreadsheet.map { FixtureImportFileReader.fixture(named: $0) }
            ?? SystemImportFileReader()
        #else
        let contacts: any ContactsImporting = SystemContactsImporter()
        let files: any ImportFileReading = SystemImportFileReader()
        #endif
        return ImportDependencies(contacts: contacts, files: files, settings: SystemSettingsOpener())
    }
}
