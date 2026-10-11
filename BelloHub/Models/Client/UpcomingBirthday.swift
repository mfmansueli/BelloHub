//
//  UpcomingBirthday.swift
//  BelloHub
//

import Foundation

struct UpcomingBirthday: Equatable, Identifiable, Sendable {
    var id: UUID { clientID }
    let clientID: UUID
    let date: Date
    let isToday: Bool
}
