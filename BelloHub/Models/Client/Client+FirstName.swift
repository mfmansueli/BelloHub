//
//  Client+FirstName.swift
//  BelloHub
//

import Foundation

extension Client {
    /// The first word of her name, for sentences such as "Save to Ana’s history". Falls back to the whole name.
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
