//
//  RegistrationReservation.swift
//  BelloHub
//

import Foundation

/// The server's answer to `reserveRegistrations` (D42): which of the claimed clients it counted (or had already
/// counted) and which it refused because the free registrations are used and there is no plan, plus its count. The
/// server owns the count; the app keeps it only as a cache (`RegistrationQuota.serverCount`).
struct RegistrationReservation: Equatable, Sendable {
    let allowed: Set<UUID>
    let refused: Set<UUID>
    let count: Int
}
