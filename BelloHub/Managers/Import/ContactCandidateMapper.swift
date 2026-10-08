//
//  ContactCandidateMapper.swift
//  BelloHub
//

import Contacts

/// Turns the contacts the picker returned into plain `ImportCandidate` values: the only place that reads a `CNContact`.
/// Each property is read only when the contact carries it (`isKeyAvailable`), because reading one that was not fetched
/// raises an exception.
enum ContactCandidateMapper {
    static func candidates(from contacts: [CNContact]) -> [ImportCandidate] {
        contacts.map(candidate(from:))
    }

    static func candidate(from contact: CNContact) -> ImportCandidate {
        ImportCandidate(
            id: contact.identifier,
            name: name(of: contact),
            phoneNumbers: phoneNumbers(of: contact),
            email: contact.isKeyAvailable(CNContactEmailAddressesKey)
                ? contact.emailAddresses.first.map { $0.value as String } : nil,
            birthday: birthday(of: contact)
        )
    }

    private static func name(of contact: CNContact) -> String {
        func text(_ key: String, _ value: String) -> String { contact.isKeyAvailable(key) ? value : "" }
        return ImportNameComposer.name(
            given: text(CNContactGivenNameKey, contact.givenName),
            family: text(CNContactFamilyNameKey, contact.familyName),
            nickname: text(CNContactNicknameKey, contact.nickname),
            organization: text(CNContactOrganizationNameKey, contact.organizationName)
        )
    }

    private static func phoneNumbers(of contact: CNContact) -> [ImportPhoneNumber] {
        guard contact.isKeyAvailable(CNContactPhoneNumbersKey) else { return [] }
        return contact.phoneNumbers.map { labeled in
            let localized = labeled.label.map(CNLabeledValue<CNPhoneNumber>.localizedString(forLabel:))
            let isMobile = labeled.label == CNLabelPhoneNumberMobile || labeled.label == CNLabelPhoneNumberiPhone
                || PhoneLabelClassifier.isMobile(localized)
            return ImportPhoneNumber(labeled.value.stringValue, isMobile: isMobile)
        }
    }

    private static func birthday(of contact: CNContact) -> Birthday? {
        guard contact.isKeyAvailable(CNContactBirthdayKey), let parts = contact.birthday,
              let month = parts.month, let day = parts.day else { return nil }
        return Birthday(month: month, day: day, year: parts.year)
    }
}
