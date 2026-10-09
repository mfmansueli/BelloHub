//
//  CalendarBandKind.swift
//  BelloHub
//

import Foundation

/// What a band behind the visits of a day is.
enum CalendarBandKind: Equatable, Sendable {
    case breakTime(label: String)
    /// A stretch she closed; the id lets her remove it.
    case blocked(id: UUID)
}
