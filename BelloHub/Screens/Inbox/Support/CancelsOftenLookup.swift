//
//  CancelsOftenLookup.swift
//  BelloHub
//

import Foundation

/// Which phones of the people asking through her link belong to a client who "cancels often" (docs/05, ClientHabits:
/// cancellations by the client and no-shows ≥ 30 % of the last ten past appointments, shown only from four completed
/// visits). The waitlist rows and the booking request use it for the same chip the client list shows. The rule itself
/// is `HabitsCalculator`'s; this type only matches people by phone. Pure.
enum CancelsOftenLookup {
    static func phones(clients: [Client], appointments: [Appointment], now: Date, calendar: Calendar) -> Set<String> {
        var byClient: [UUID: [Appointment]] = [:]
        for appointment in appointments { byClient[appointment.clientID, default: []].append(appointment) }
        var phones = Set<String>()
        for client in clients where !client.isArchived {
            guard let phone = normalized(client.phoneE164), let visits = byClient[client.id] else { continue }
            let habits = HabitsCalculator.habits(for: client.id, appointments: visits, now: now, calendar: calendar)
            if habits.cancelsOften { phones.insert(phone) }
        }
        return phones
    }

    static func cancelsOften(phone: String?, in phones: Set<String>) -> Bool {
        normalized(phone).map(phones.contains) ?? false
    }

    private static func normalized(_ phone: String?) -> String? {
        let trimmed = phone?.filter { !$0.isWhitespace }
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
