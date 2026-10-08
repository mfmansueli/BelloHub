//
//  FakeSettingsOpener.swift
//  BelloHubTests
//

@testable import BelloHub

/// Counts how many times the screen asked to open Settings.
@MainActor
final class FakeSettingsOpener: SettingsOpening {
    private(set) var openCount = 0

    func openSettings() {
        openCount += 1
    }
}
