//
//  ClientsRoute.swift
//  BelloHub
//

import Foundation

/// Where the Clients tab can go, as a typed route on its `NavigationStack` (docs/04-ARCHITECTURE.md section 5). The tab
/// owns the stack and the `navigationDestination`; each case is one screen.
enum ClientsRoute: Hashable, Sendable {
    /// 4.1 ClientProfile.
    case profile(clientID: UUID)
    /// 4.3 ClientEdit.
    case edit(clientID: UUID)
    /// 4.4 ClientKnowledge.
    case knowledge(clientID: UUID)
    /// 4.5 ClientHealth.
    case health(clientID: UUID)
}
