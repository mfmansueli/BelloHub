//
//  SystemSettingsOpener.swift
//  BelloHub
//

import UIKit

/// The real Settings opener: `UIApplication.openSettingsURLString` is the app's own page in Settings.
@MainActor
final class SystemSettingsOpener: SettingsOpening {
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
