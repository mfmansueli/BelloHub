//
//  MainTab.swift
//  BelloHub
//

/// The five tabs of the app, in the order of the tab bar (docs/04-ARCHITECTURE.md section 5).
enum MainTab: String, CaseIterable, Hashable, Identifiable, Sendable {
    case home
    case clients
    case calendar
    case alerts
    case more

    var id: String { rawValue }
}
