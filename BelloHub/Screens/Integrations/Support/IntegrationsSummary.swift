//
//  IntegrationsSummary.swift
//  BelloHub
//

/// How each row of Integrations (7.6) reads, from the facts: Apple Calendar from the access and the switch, Google
/// Calendar not built (H9), WhatsApp and the Instagram bio link always available (they open other screens or apps),
/// contacts import always available (the picker needs no permission, ASSUMPTION-39). Pure and tested.
struct IntegrationsSummary: Equatable, Sendable {
    let appleCalendar: IntegrationState
    let googleCalendar: IntegrationState
    let whatsApp: IntegrationState
    let instagram: IntegrationState
    let contacts: IntegrationState

    init(calendarAccess: CalendarAccessStatus, calendarEnabled: Bool, messagingChannel: MessagingChannel?) {
        appleCalendar = Self.appleCalendarState(access: calendarAccess, enabled: calendarEnabled)
        googleCalendar = .comingSoon
        whatsApp = messagingChannel == .messages ? .available : .connected
        instagram = .available
        contacts = .available
    }

    static func appleCalendarState(access: CalendarAccessStatus, enabled: Bool) -> IntegrationState {
        switch access {
        case .denied: .deniedInSettings
        case .full, .writeOnly: enabled ? .connected : .available
        case .notDetermined: .available
        }
    }
}
