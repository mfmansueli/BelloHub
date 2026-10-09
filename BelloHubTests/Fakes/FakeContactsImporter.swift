//
//  FakeContactsImporter.swift
//  BelloHubTests
//

@testable import BelloHub

/// A contact source a test scripts: the contacts it "picks", whether access is restricted, and how often it was asked.
@MainActor
final class FakeContactsImporter: ContactsImporting {
    var access: ContactsAccess
    var contacts: [ImportCandidate]
    private(set) var pickCount = 0
    private(set) var isPickerPresented = false

    init(contacts: [ImportCandidate] = [], access: ContactsAccess = .available) {
        self.contacts = contacts
        self.access = access
    }

    func pickContacts() async -> [ImportCandidate] {
        pickCount += 1
        return contacts
    }

    func finishPicking(_ candidates: [ImportCandidate]?) {}
}
