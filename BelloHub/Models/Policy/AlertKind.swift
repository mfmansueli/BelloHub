//
//  AlertKind.swift
//  BelloHub
//

/// What an alert is about, for quiet-hours decisions. Generic: no client names (docs/06-PRIVACY-SECURITY.md section 8).
enum AlertKind: String, CaseIterable, Sendable {
    case newBooking
    case cancellation
    case clientRunningLate
    case clientCheckIn
    case formReceived
    case followUpsDue
    case birthday
    case dailySummary
}
