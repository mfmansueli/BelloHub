//
//  AppointmentAddOn.swift
//  BelloHub
//

import Foundation

/// An extra the client ticked, copied at booking time so a later edit of the add-on does not rewrite history.
struct AppointmentAddOn: Hashable, Codable, Sendable {
    let addOnID: UUID
    let name: String
    let minutes: Int
}
