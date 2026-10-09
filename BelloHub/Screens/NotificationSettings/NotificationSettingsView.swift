//
//  NotificationSettingsView.swift
//  BelloHub
//

import SwiftUI

/// 7.4 Notification settings, as More opens it. Reads the Service from the environment and hands it to
/// `NotificationSettingsContentView`, which owns the ViewModel.
struct NotificationSettingsView: View {
    @Environment(NotificationSettingsService.self) private var service

    var body: some View {
        NotificationSettingsContentView(service: service)
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
        .environment(NotificationSettingsService(permissions: PermissionService()))
}
