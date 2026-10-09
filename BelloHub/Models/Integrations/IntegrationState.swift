//
//  IntegrationState.swift
//  BelloHub
//

/// How an integration row reads: connected, something she can connect, or not built yet (Google Calendar, H9).
enum IntegrationState: Equatable, Sendable {
    case connected
    case available
    /// Not offered yet; the row says "coming soon" and does nothing.
    case comingSoon
    /// Access was refused on this iPhone; the row sends her to Settings.
    case deniedInSettings
}
