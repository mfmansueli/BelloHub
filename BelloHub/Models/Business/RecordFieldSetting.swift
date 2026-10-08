//
//  RecordFieldSetting.swift
//  BelloHub
//

import Foundation

/// One field of the treatment record, switched on or off for one profession. The `key` is stable across languages
/// (`skinCondition`); the visible name comes from the profession catalog in the business language, or from
/// `customName` for a field she added herself.
struct RecordFieldSetting: Identifiable, Hashable, Codable, Sendable {
    var profession: ProfessionID
    var key: String
    var customName: String?
    var isOn: Bool

    var id: String { "\(profession.rawValue)|\(key)" }

    init(profession: ProfessionID, key: String, customName: String? = nil, isOn: Bool) {
        self.profession = profession
        self.key = key
        self.customName = customName
        self.isOn = isOn
    }
}
