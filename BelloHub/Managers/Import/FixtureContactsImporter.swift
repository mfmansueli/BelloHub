//
//  FixtureContactsImporter.swift
//  BelloHub
//

#if DEBUG
import Observation

/// A contact source for UI tests and previews (`-uiContacts four`): it answers at once with fixed contacts, so a test
/// never has to drive the system's contact picker. DEBUG only.
@MainActor
@Observable
final class FixtureContactsImporter: ContactsImporting {
    let access: ContactsAccess
    private let contacts: [ImportCandidate]
    private(set) var isPickerPresented = false

    init(contacts: [ImportCandidate], access: ContactsAccess = .available) {
        self.contacts = contacts
        self.access = access
    }

    func pickContacts() async -> [ImportCandidate] { contacts }

    func finishPicking(_ candidates: [ImportCandidate]?) {}

    /// The fixture a `-uiContacts` value names. Only `four` exists: the prototype's four contacts, written with the
    /// country code so they are valid whatever region the test runs in.
    static func fixture(named name: String) -> FixtureContactsImporter {
        FixtureContactsImporter(contacts: [
            contact("bianca", "Bianca Nunes", "+55 11 98123-4410"),
            contact("carla", "Carla Mendes", "+55 11 97766-2031"),
            contact("daniela", "Daniela Souza", "+55 11 99402-1187"),
            contact("eduarda", "Eduarda Pires", "+55 11 96655-7302")
        ])
    }

    private static func contact(_ id: String, _ name: String, _ phone: String) -> ImportCandidate {
        ImportCandidate(id: "fixture-\(id)", name: name, phoneNumbers: [ImportPhoneNumber(phone, isMobile: true)])
    }
}
#endif
