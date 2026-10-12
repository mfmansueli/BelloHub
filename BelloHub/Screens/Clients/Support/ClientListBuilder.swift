//
//  ClientListBuilder.swift
//  BelloHub
//

import Foundation

/// Turns the vault's clients and appointments into the entries of the Clients list. Every rule that says something
/// about a client's history is asked of its owner (`HabitsCalculator` for "cancels often" and its four-visit
/// threshold, `FollowUpPlanner` for "due to return" and "haven't been back"); nothing is re-implemented here.
///
/// The owners filter the appointments they get by client, so each client is handed only her own: the work grows with
/// the number of appointments, not with clients times appointments (2,000 clients stay fast).
enum ClientListBuilder {
    static func build(
        clients: [Client], appointments: [Appointment], services: [Service], walkIns: [RecordMark] = [], now: Date,
        calendar: Calendar
    ) -> ClientList {
        let appointmentsByClient = Dictionary(grouping: appointments, by: \.clientID)
        let walkInsByClient = Dictionary(grouping: walkIns.filter(\.isWalkInVisit), by: \.clientID)
        var entries: [ClientListEntry] = []
        entries.reserveCapacity(clients.count)
        var winBack: [WinBackCandidate] = []
        for client in clients {
            let own = appointmentsByClient[client.id] ?? []
            let habits = HabitsCalculator.habits(for: client.id, appointments: own, now: now, calendar: calendar)
            let isDue = !FollowUpPlanner.dueFollowUps(
                clients: [client], appointments: own, services: services, now: now, calendar: calendar
            ).isEmpty
            winBack += FollowUpPlanner.winBack(clients: [client], appointments: own, now: now, calendar: calendar)
            let walkIns = walkInsByClient[client.id] ?? []
            // A client seen only as a walk-in has been seen: she is not "New".
            entries.append(ClientListEntry(
                client: client, habits: habits, summary: .make(appointments: own, walkIns: walkIns, now: now),
                isDueToReturn: isDue, isNew: habits.visits == 0 && walkIns.isEmpty
            ))
        }
        return ClientList(
            entries: ClientSort.sorted(entries),
            winBack: winBack.sorted { $0.daysSinceLastVisit > $1.daysSinceLastVisit }
        )
    }
}
