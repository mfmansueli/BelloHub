//
//  RecordFieldSetting.swift
//  BelloHub
//

import Foundation

/// One field of the treatment record, switched on or off for one profession. The `key` is stable across languages
/// (`skinCondition`, or `custom-<uuid>` for a field she added); the visible name comes from the profession catalog in
/// the business language, or from `customName` for a field she added herself.
///
/// Switching a field off only stops it being asked: what a saved treatment record already holds for that key is never
/// touched by the template (the record keeps its own values, keyed by `key`).
///
/// `kind`, `options` and `unit` arrived after the first build (S3 stored only the four properties above), so decoding
/// treats all three as optional: a value saved by that build reads back as a free-text field. `isRequired` and
/// `serviceIDs` came later still and read back as "not required" and "every service".
struct RecordFieldSetting: Identifiable, Hashable, Codable, Sendable {
    /// Keys of the fields she adds start with this, followed by a UUID that never changes and is never reused.
    static let customKeyPrefix = "custom-"

    var profession: ProfessionID
    var key: String
    var customName: String?
    var isOn: Bool
    var kind: RecordFieldKind
    /// The choices of a `.choice` field, in the order she listed them. Empty for the other kinds.
    var options: [String]
    /// What a `.number` field is measured in ("mm"). Nil when she gave none.
    var unit: String?
    /// Needed before a record can be finalized. Never needed to save a draft.
    var isRequired: Bool
    /// The services this field is asked for; empty means every service.
    var serviceIDs: [UUID]

    var id: String { "\(profession.rawValue)|\(key)" }

    /// Whether she created this field (the catalog's fields never carry a custom name).
    var isCustom: Bool { customName != nil }

    /// Whether the visit form asks this field for a visit of `serviceID`. A visit with no service known yet asks
    /// every field, so nothing is hidden before she says what was done.
    func applies(toService serviceID: UUID?) -> Bool {
        guard let serviceID, !serviceIDs.isEmpty else { return true }
        return serviceIDs.contains(serviceID)
    }

    init(
        profession: ProfessionID,
        key: String,
        customName: String? = nil,
        isOn: Bool,
        kind: RecordFieldKind = .text,
        options: [String] = [],
        unit: String? = nil,
        isRequired: Bool = false,
        serviceIDs: [UUID] = []
    ) {
        self.profession = profession
        self.key = key
        self.customName = customName
        self.isOn = isOn
        self.kind = kind
        self.options = options
        self.unit = unit
        self.isRequired = isRequired
        self.serviceIDs = serviceIDs
    }

    private enum CodingKeys: String, CodingKey {
        case profession, key, customName, isOn, kind, options, unit, isRequired, serviceIDs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profession = try container.decode(ProfessionID.self, forKey: .profession)
        key = try container.decode(String.self, forKey: .key)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        isOn = try container.decode(Bool.self, forKey: .isOn)
        kind = try container.decodeIfPresent(RecordFieldKind.self, forKey: .kind) ?? .text
        options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        serviceIDs = try container.decodeIfPresent([UUID].self, forKey: .serviceIDs) ?? []
    }
}
