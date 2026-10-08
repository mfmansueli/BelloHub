//
//  ImportCandidate.swift
//  BelloHub
//

import Foundation

/// One person found in a source (a contact she picked, a row of a spreadsheet), before any rule was applied. Plain
/// values only: nothing here knows the Contacts framework or a file, so the mapper that turns it into a `Client` is
/// tested without either. Nothing from a candidate is kept unless it becomes a client.
struct ImportCandidate: Identifiable, Hashable, Sendable {
    /// Stable inside one import: the contact's identifier, or `row-<number>` for a spreadsheet row.
    let id: String
    /// The name as found, already assembled from the parts the source has (given, family, organization).
    var name: String
    var phoneNumbers: [ImportPhoneNumber]
    var email: String?
    var birthday: Birthday?
    /// The row number in the spreadsheet as Excel and Numbers count it (1 is the first row, the header included).
    /// Nil for contacts.
    var rowNumber: Int?

    init(
        id: String,
        name: String,
        phoneNumbers: [ImportPhoneNumber] = [],
        email: String? = nil,
        birthday: Birthday? = nil,
        rowNumber: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneNumbers = phoneNumbers
        self.email = email
        self.birthday = birthday
        self.rowNumber = rowNumber
    }
}

/// A phone number as the source wrote it, with whether the source says it is a mobile (the number WhatsApp uses).
struct ImportPhoneNumber: Hashable, Sendable {
    let raw: String
    let isMobile: Bool

    init(_ raw: String, isMobile: Bool = false) {
        self.raw = raw
        self.isMobile = isMobile
    }
}
