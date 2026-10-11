//
//  SlotPreview.swift
//  BelloHub
//

import Foundation

/// The sample day "What clients see" draws (routine item 10): the times a client would be offered for one service on
/// her next working day, with one sample visit already booked so the anchoring and the compact day show. Built by
/// `SlotPreviewBuilder`; every time is a real answer of `FreeSlotsCalculator`.
struct SlotPreview: Equatable, Sendable {
    /// The visit already in the sample day, so she sees times fit around a booking.
    struct SampleVisit: Equatable, Sendable {
        let serviceName: String
        let start: Date
        let minutes: Int
    }

    /// The local day the sample uses (start of day in her time zone).
    let day: Date
    /// The service previewed; nil when she has no services and a plain 60-minute visit stands in.
    let serviceName: String?
    let durationMinutes: Int
    let sampleVisit: SampleVisit?
    /// The times shown first on her page.
    let shownFirst: [Date]
    /// The other bookable times, behind "Show all times" on her page.
    let alsoBookable: [Date]

    var isEmpty: Bool { shownFirst.isEmpty && alsoBookable.isEmpty }
}
