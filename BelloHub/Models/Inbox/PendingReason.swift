//
//  PendingReason.swift
//  BelloHub
//

/// Why a booking waits for her approval (API.md section 8, `pendingReason`). Set by the server only.
enum PendingReason: String, PersistedEnum {
    /// She asked to confirm new clients.
    case newClient
    /// Her free registrations are used and the client is new (D42): approving needs a plan.
    case freeRegistrationsUsed
    /// The client reached her no-show limit (D13).
    case noShowLimit

    static let fallback = PendingReason.newClient
}
