//
//  FollowUpAction.swift
//  BelloHub
//

import Foundation

/// What the next action of a queue item opens (routine-a item 5): a message sheet with the text ready, the new
/// appointment sheet, or the visit's closing. One owner, so the queue and Home never disagree. Pure.
enum FollowUpAction: Equatable, Sendable {
    case sheet(AgendaSheet)
    case resumeVisit(TreatmentFlowRequest)

    /// The item's main action.
    static func primary(for item: FollowUpItem) -> FollowUpAction? {
        switch item.kind {
        case .reminder, .postVisit:
            return item.appointmentID.map { .sheet(.message(appointmentID: $0)) }
        case .unfinishedVisit:
            guard let recordID = item.recordID else { return nil }
            return .resumeVisit(TreatmentFlowRequest(
                clientID: item.clientID, appointmentID: item.appointmentID, resumeRecordID: recordID
            ))
        case .returnDue:
            let request = ClientMessageRequest(
                clientID: item.clientID, kind: .followUp(serviceName: item.serviceName ?? "")
            )
            return .sheet(.clientMessage(request))
        case .notBack:
            return .sheet(.clientMessage(ClientMessageRequest(clientID: item.clientID, kind: .winBack)))
        case .birthday:
            return .sheet(.clientMessage(ClientMessageRequest(clientID: item.clientID, kind: .birthday)))
        }
    }

    /// "Book" next to the message, for the reasons that end in a new visit.
    static func offersBooking(_ item: FollowUpItem) -> Bool {
        item.kind == .returnDue || item.kind == .notBack
    }

    /// Reasons whose message can be marked as sent by her once the chat was opened.
    static func offersMarkSent(_ item: FollowUpItem) -> Bool {
        item.delivery.isOpened && item.kind != .unfinishedVisit
    }

    /// The main action's title.
    static func title(for kind: FollowUpKind) -> LocalizedStringResource {
        switch kind {
        case .reminder: LocalizedStringResource("followUpQueue.action.remind", defaultValue: "Send reminder")
        case .unfinishedVisit: LocalizedStringResource("followUpQueue.action.continue", defaultValue: "Continue")
        case .postVisit: LocalizedStringResource("followUpQueue.action.checkIn", defaultValue: "Check in")
        case .returnDue, .notBack: LocalizedStringResource("followUpQueue.action.message", defaultValue: "Message")
        case .birthday: LocalizedStringResource("followUpQueue.action.wishes", defaultValue: "Send wishes")
        }
    }
}
