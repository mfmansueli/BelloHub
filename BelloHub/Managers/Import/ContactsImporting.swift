//
//  ContactsImporting.swift
//  BelloHub
//

/// Whether the system lets the app show its contact picker on this iPhone.
enum ContactsAccess: Equatable, Sendable {
    case available
    /// A restriction (Screen Time, a device-management profile) keeps every app out of the contacts. She cannot change
    /// it inside Bello Hub, so the screen explains it and offers Settings and the spreadsheet instead.
    case restricted
}

/// How the import gets the contacts she chooses. The real one shows the system's own contact picker, which runs outside
/// the app: it needs **no permission**, and the app only ever receives the contacts she tapped (never the address
/// book). A test passes a fake that answers at once.
@MainActor
protocol ContactsImporting: AnyObject {
    var access: ContactsAccess { get }

    /// Shows the picker and returns the contacts she chose, or nothing when she cancelled.
    func pickContacts() async -> [ImportCandidate]

    /// True while the system picker should be on screen. `.contactPicker(for:)` presents it.
    var isPickerPresented: Bool { get }

    /// Called by the picker when it closes: the contacts she chose, or nil when she cancelled.
    func finishPicking(_ candidates: [ImportCandidate]?)
}
