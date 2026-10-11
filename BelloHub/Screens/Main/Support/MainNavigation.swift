//
//  MainNavigation.swift
//  BelloHub
//

import Observation

/// Where she is in the app: the selected tab and the More stack. `RootView` keeps it above `MainView`, so the place
/// survives `MainView` being built again: after a lock and unlock, and when she changes the interface language (the
/// whole tab view is rebuilt then, so navigation titles, tab names and every open screen are in the new language at
/// once; routine-a item 1). Cleared at sign-out.
@MainActor
@Observable
final class MainNavigation {
    var selection: MainTab = .home
    var morePath: [MoreRoute] = []

    func reset() {
        selection = .home
        morePath = []
    }
}
