//
//  SharePayload.swift
//  BelloHub
//

import Foundation

/// A message for the system share sheet, the last stop when neither WhatsApp nor Messages could open. `Identifiable`
/// so a sheet can be presented from an optional of it.
struct SharePayload: Identifiable, Equatable, Sendable {
    let id = UUID()
    let text: String
}
