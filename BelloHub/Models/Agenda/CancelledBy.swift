//
//  CancelledBy.swift
//  BelloHub
//

/// Who cancelled. A cancellation by the professional never counts against a client (D13).
enum CancelledBy: String, PersistedEnum {
    case client
    case professional

    /// An unknown value must never be read as the client's fault.
    static let fallback = CancelledBy.professional
}
