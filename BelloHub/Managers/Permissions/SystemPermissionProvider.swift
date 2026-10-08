//
//  SystemPermissionProvider.swift
//  BelloHub
//

import AVFoundation
import Contacts
import UserNotifications

/// The real permission dialogs: microphone, notifications, camera and contacts.
struct SystemPermissionProvider: PermissionProviding {
    func status(of kind: PermissionKind) async -> PermissionStatus {
        switch kind {
        case .microphone: microphoneStatus()
        case .camera: cameraStatus()
        case .contacts: contactsStatus()
        case .notifications: await notificationsStatus()
        }
    }

    func request(_ kind: PermissionKind) async -> PermissionStatus {
        let allowed: Bool
        switch kind {
        case .microphone: allowed = await AVAudioApplication.requestRecordPermission()
        case .camera: allowed = await AVCaptureDevice.requestAccess(for: .video)
        case .contacts: allowed = (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        case .notifications: allowed = await requestNotifications()
        }
        return allowed ? .granted : .denied
    }

    // MARK: - Status

    private func microphoneStatus() -> PermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        default: .notDetermined
        }
    }

    private func cameraStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func contactsStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func notificationsStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }
}
