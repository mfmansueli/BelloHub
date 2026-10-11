//
//  SystemContactsImporter.swift
//  BelloHub
//

import Contacts
import Observation

/// The real contact source: it asks the system's contact picker (`CNContactPickerViewController`, in
/// `ContactPickerSheet`) to run and waits for her answer. The picker returns only the contacts she tapped, so no
/// Contacts permission is requested and the rest of the address book is never read. The candidates it returns hold
/// plain values; nothing from them is kept unless it becomes a client.
@MainActor
@Observable
final class SystemContactsImporter: ContactsImporting {
    private(set) var isPickerPresented = false
    @ObservationIgnored private var pending: CheckedContinuation<[ImportCandidate], Never>?

    var access: ContactsAccess {
        CNContactStore.authorizationStatus(for: .contacts) == .restricted ? .restricted : .available
    }

    func pickContacts() async -> [ImportCandidate] {
        // One picker at a time: a second call while it is open answers at once with nothing.
        guard pending == nil else { return [] }
        return await withCheckedContinuation { continuation in
            pending = continuation
            isPickerPresented = true
        }
    }

    func finishPicking(_ candidates: [ImportCandidate]?) {
        isPickerPresented = false
        pending?.resume(returning: candidates ?? [])
        pending = nil
    }
}
