//
//  FollowUpKind.swift
//  BelloHub
//

/// Why a client is in the follow-up queue (routine-a item 5). The order is the urgency: a row's main action is its
/// most urgent reason.
enum FollowUpKind: String, CaseIterable, Codable, Sendable {
    /// A visit coming up whose reminder can be sent (D31).
    case reminder
    /// A visit she left with "Finish later" (item 7).
    case unfinishedVisit
    /// A visit of today or yesterday: a short check-in is optional.
    case postVisit
    /// The usual interval of her last service has passed and nothing is booked.
    case returnDue
    /// Two months or more since the last visit and nothing booked (win back).
    case notBack
    case birthday

    var priority: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Suggestions she may snooze or dismiss. A reminder is about a booked visit and an unfinished visit is her own
    /// work, so they only leave the list when done.
    var canBeSetAside: Bool {
        switch self {
        case .reminder, .unfinishedVisit: false
        case .postVisit, .returnDue, .notBack, .birthday: true
        }
    }

    /// The template the message log keeps for the chats this reason opens (`MessageLog.template`), so the queue can
    /// tell that a conversation was opened. Nil when the reason does not open a chat.
    var messageTemplates: Set<String> {
        switch self {
        case .reminder: ["reminder", "confirm"]
        case .unfinishedVisit: []
        case .postVisit: ["aftercare", "checkIn"]
        case .returnDue: ["followUp"]
        case .notBack: ["winBack", "comeBack"]
        case .birthday: ["birthday"]
        }
    }
}
