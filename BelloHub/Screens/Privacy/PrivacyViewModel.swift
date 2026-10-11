//
//  PrivacyViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Privacy and security (7.7): the lock switch and its grace, the lock-screen names switch, the
/// recovery-key status and the legal texts to read.
@MainActor
@Observable
final class PrivacyViewModel {
    private(set) var openedNotice: LegalNoticeText?
    private(set) var legalErrorMessage: String?
    private(set) var lockEnabled: Bool
    private(set) var graceSeconds: Int

    private let lock: AppLockService
    private let recoveryKey: RecoveryKeyService
    private let notifications: NotificationSettingsService
    private let legal: any LegalNoticeLibrary
    let localization: AppLocalization

    init(
        lock: AppLockService, recoveryKey: RecoveryKeyService, notifications: NotificationSettingsService,
        legal: any LegalNoticeLibrary = BundleLegalNoticeLibrary(), localization: AppLocalization
    ) {
        self.lock = lock
        self.recoveryKey = recoveryKey
        self.notifications = notifications
        self.legal = legal
        self.localization = localization
        lockEnabled = lock.isEnabled
        graceSeconds = lock.graceSeconds
    }

    // MARK: - Reading

    var recoveryStatus: RecoveryKeyStatus { recoveryKey.status }
    var biometryKind: BiometryKind { lock.biometryKind }
    var hideNames: Bool { notifications.hideNamesOnLockScreen }
    var graceOptions: [Int] { LockPolicy.graceOptions }

    // MARK: - Lock

    func setLockEnabled(_ value: Bool) {
        lock.setEnabled(value)
        lockEnabled = lock.isEnabled
    }

    func setGraceSeconds(_ seconds: Int) {
        lock.setGraceSeconds(seconds)
        graceSeconds = lock.graceSeconds
    }

    // MARK: - Notifications

    func setHideNames(_ value: Bool) {
        notifications.setHideNamesOnLockScreen(value)
    }

    // MARK: - Legal

    func open(_ notice: LegalNotice) {
        do {
            openedNotice = try legal.latest(notice, localization: localization)
            legalErrorMessage = nil
        } catch {
            legalErrorMessage = String(interface: LocalizedStringResource(
                "privacy.legal.error", defaultValue: "This text could not be opened right now."
            ))
        }
    }

    func closeNotice() {
        openedNotice = nil
    }
}
