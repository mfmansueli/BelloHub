//
//  ContactCandidateMapperTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Contacts
import Foundation
import Testing

/// The one place that reads a `CNContact`. The contacts are built in memory (no address book, no permission).
@Suite("ContactCandidateMapper")
struct ContactCandidateMapperTests {
    private func makeContact(
        given: String = "Ana", family: String = "Costa", organization: String = "",
        phones: [(label: String?, number: String)] = [], emails: [String] = [], birthday: DateComponents? = nil
    ) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = given
        contact.familyName = family
        contact.organizationName = organization
        contact.phoneNumbers = phones.map {
            CNLabeledValue(label: $0.label, value: CNPhoneNumber(stringValue: $0.number))
        }
        contact.emailAddresses = emails.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
        contact.birthday = birthday
        return contact
    }

    @Test("A contact becomes a candidate with its identifier, name, phones and e-mail")
    func basic() {
        let contact = makeContact(
            phones: [(CNLabelPhoneNumberMobile, "(11) 98765-4321")], emails: ["ana@example.com"]
        )

        let candidate = ContactCandidateMapper.candidate(from: contact)

        #expect(candidate.id == contact.identifier)
        #expect(candidate.name == "Ana Costa")
        #expect(candidate.phoneNumbers == [ImportPhoneNumber("(11) 98765-4321", isMobile: true)])
        #expect(candidate.email == "ana@example.com")
        #expect(candidate.rowNumber == nil)
    }

    @Test("The mobile and iPhone labels are mobile; home and work are not")
    func labels() {
        let contact = makeContact(phones: [
            (CNLabelHome, "1"), (CNLabelWork, "2"), (CNLabelPhoneNumberMobile, "3"), (CNLabelPhoneNumberiPhone, "4"),
            (nil, "5"), ("Celular da Ana", "6")
        ])

        let mobile = ContactCandidateMapper.candidate(from: contact).phoneNumbers.map(\.isMobile)

        #expect(mobile == [false, false, true, true, false, true])
    }

    @Test("A contact saved only as an organization is named after it")
    func organizationOnly() {
        let contact = makeContact(given: "", family: "", organization: "Studio Bela")

        #expect(ContactCandidateMapper.candidate(from: contact).name == "Studio Bela")
    }

    @Test("A contact with no name at all has an empty name, which the importer reports as malformed")
    func noName() {
        let contact = makeContact(given: "", family: "", phones: [(nil, "11 98765-4321")])

        #expect(ContactCandidateMapper.candidate(from: contact).name == "")
    }

    @Test("A birthday with a year and one without")
    func birthdays() {
        let withYear = makeContact(birthday: DateComponents(year: 1990, month: 4, day: 12))
        let withoutYear = makeContact(birthday: DateComponents(month: 12, day: 31))
        let none = makeContact()

        #expect(ContactCandidateMapper.candidate(from: withYear).birthday == Birthday(month: 4, day: 12, year: 1990))
        #expect(ContactCandidateMapper.candidate(from: withoutYear).birthday == Birthday(month: 12, day: 31, year: nil))
        #expect(ContactCandidateMapper.candidate(from: none).birthday == nil)
    }

    @Test("Several contacts keep the order given")
    func many() {
        let contacts = [makeContact(given: "Bia"), makeContact(given: "Ana"), makeContact(given: "Carla")]

        let names = ContactCandidateMapper.candidates(from: contacts).map(\.name)

        #expect(names == ["Bia Costa", "Ana Costa", "Carla Costa"])
    }
}
