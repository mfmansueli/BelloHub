//
//  AlertBlockIDs.swift
//  BelloHub
//

import Foundation

/// The identities of the cards of Alerts, in order, for `motionRows`: a request she answers or a check-in she handles
/// leaves where she can see it, and a new one enters from above (docs/09-MOTION.md section 3.10). Pure.
enum AlertBlockIDs {
    static func make(list: AlertsList, inbox: InboxAlerts, mailbox: MailboxAlerts, reachOut: Int) -> [String] {
        var ids: [String] = []
        ids += inbox.bookingRequests.map { "request.\($0.id)" }
        ids += inbox.reschedules.map { "reschedule.\($0.id)" }
        if inbox.waitingCount > 0 { ids.append("waitlist") }
        if mailbox.importedCount > 0 { ids.append("imported") }
        ids += mailbox.items.map { "mailbox.\($0.id)" }
        if let visit = list.upcomingVisit { ids.append("upcoming.\(visit.id.uuidString)") }
        if reachOut > 0 { ids.append("reachOut") }
        return ids
    }
}
