//
//  IntakeSetting.swift
//  BelloHub
//

import Foundation

/// Whether one intake item is on for one profession.
struct IntakeSetting: Identifiable, Hashable, Codable, Sendable {
    var profession: ProfessionID
    var item: IntakeItem
    var isOn: Bool

    var id: String { "\(profession.rawValue)|\(item.rawValue)" }
}
