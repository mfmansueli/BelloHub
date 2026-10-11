//
//  ImportNameComposer.swift
//  BelloHub
//

import Foundation

/// The name of a contact from the parts the address book keeps: "given family", else the nickname, else the
/// organization (a contact saved only as "Studio Bela" is still somebody she can import). Pure, so the fallback order
/// is tested without the Contacts framework.
enum ImportNameComposer {
    static func name(given: String, family: String, nickname: String = "", organization: String = "") -> String {
        let person = [given, family].map(clean).filter { !$0.isEmpty }.joined(separator: " ")
        if !person.isEmpty { return person }
        let nick = clean(nickname)
        if !nick.isEmpty { return nick }
        return clean(organization)
    }

    private static func clean(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
