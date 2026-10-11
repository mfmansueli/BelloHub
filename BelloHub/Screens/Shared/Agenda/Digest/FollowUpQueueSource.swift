//
//  FollowUpQueueSource.swift
//  BelloHub
//

import Foundation

/// Where Home, Alerts and the follow-up queue get the one `FollowUpQueue`: the day's digest, every visit and client,
/// the chats opened lately and her decisions and visit closings, put through the pure rule at the moment the screen
/// asks. Reading the services' properties inside the call keeps the SwiftUI bodies in step with the vault.
@MainActor
struct FollowUpQueueSource {
    let digest: AgendaDigestSource
    let queue: FollowUpQueueService

    func make(now: Date) -> FollowUpQueue {
        let service = digest.service
        return FollowUpQueue.make(
            FollowUpQueue.Input(
                digest: digest.digest(now: now), appointments: service.appointments, clients: service.clients,
                messageLogs: queue.messageLogs, decisions: queue.decisions, closings: Array(queue.closings.values),
                now: now, calendar: digest.days.calendar
            )
        )
    }
}
