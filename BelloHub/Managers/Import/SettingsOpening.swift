//
//  SettingsOpening.swift
//  BelloHub
//

/// Opens this app's page in the system Settings, so a screen that explains a blocked permission can send her there.
@MainActor
protocol SettingsOpening: AnyObject {
    func openSettings()
}
