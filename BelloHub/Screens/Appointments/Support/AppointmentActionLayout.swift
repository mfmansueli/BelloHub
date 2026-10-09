//
//  AppointmentActionLayout.swift
//  BelloHub
//

/// The actions of a visit in the three places the detail puts them: one main button, a row of tiles and the text
/// links under them.
struct AppointmentActionLayout: Equatable, Sendable {
    let primary: AppointmentAction?
    let quick: [AppointmentAction]
    let secondary: [AppointmentAction]

    var all: [AppointmentAction] {
        (primary.map { [$0] } ?? []) + quick + secondary
    }
}
