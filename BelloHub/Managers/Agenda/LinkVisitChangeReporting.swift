//
//  LinkVisitChangeReporting.swift
//  BelloHub
//

/// Who hears about a change she made to a link visit (`BookingSyncService`, which sends it to the server through the
/// outbound queue). `AppointmentService` reports every such change, so no screen can forget to.
@MainActor
protocol LinkVisitChangeReporting: AnyObject {
    func linkVisitChanged(_ change: LinkVisitChange)
}
