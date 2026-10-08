//
//  AppLockServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("AppLockService")
struct AppLockServiceTests {
    private struct Rig {
        let lock: AppLockService
        let keys: KeyManager
        let biometrics: FakeBiometrics
        let clock: MutableClock
        let defaults: UserDefaults
        let suite: String
    }

    private func makeRig(
        _ results: [BiometricResult] = [.success], seed: Data? = Data(repeating: 9, count: 16)
    ) -> Rig {
        let suite = "test.lock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let keys = KeyManager(store: InMemoryKeyStore(seed: seed))
        let biometrics = FakeBiometrics(results)
        let clock = MutableClock()
        let lock = AppLockService(keyManager: keys, biometrics: biometrics, defaults: defaults) { clock.now }
        return Rig(lock: lock, keys: keys, biometrics: biometrics, clock: clock, defaults: defaults, suite: suite)
    }

    @Test("A cold launch of a set-up workspace is locked and has no keys in memory")
    func coldLaunch() throws {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        try rig.keys.prepare(createIfMissing: false)
        #expect(rig.keys.status == .unlocked)

        rig.lock.prepareForLaunch()

        #expect(rig.lock.isLocked)
        #expect(rig.keys.status == .locked)
    }

    @Test("A cold launch with the lock turned off opens straight away")
    func coldLaunchDisabled() {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.defaults.set(false, forKey: DefaultsKey.lockEnabled)

        rig.lock.prepareForLaunch()

        #expect(!rig.lock.isLocked)
        #expect(rig.keys.status == .unlocked)
        #expect(rig.biometrics.calls == 0)
    }

    @Test("Face ID success opens the vault")
    func unlockSuccess() async {
        let rig = makeRig([.success])
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.lock.prepareForLaunch()

        await rig.lock.unlock()

        #expect(!rig.lock.isLocked)
        #expect(rig.keys.status == .unlocked)
        #expect(rig.lock.failure == nil)
    }

    @Test("A face that does not match stays locked and says so; cancelling says nothing")
    func unlockFailure() async {
        let rig = makeRig([.failed, .cancelled, .success])
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.lock.prepareForLaunch()

        await rig.lock.unlock()
        #expect(rig.lock.isLocked)
        #expect(rig.lock.failure == .notRecognized)

        await rig.lock.unlock()
        #expect(rig.lock.isLocked)

        await rig.lock.unlock()
        #expect(!rig.lock.isLocked)
        #expect(rig.lock.failure == nil)
        #expect(rig.biometrics.calls == 3)
    }

    @Test("A phone with no passcode cannot ask, so the vault opens")
    func unavailable() async {
        let rig = makeRig([.unavailable])
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.lock.prepareForLaunch()
        await rig.lock.unlock()
        #expect(!rig.lock.isLocked)
    }

    @Test("A phone with no key for her records says so and stays locked")
    func keyMissing() async {
        let rig = makeRig([.success], seed: nil)
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.lock.prepareForLaunch()

        await rig.lock.unlock()

        #expect(rig.lock.isLocked)
        #expect(rig.lock.failure == .keyMissing)
        #expect(rig.keys.status == .needsRestore)
    }

    @Test("Returning after the grace period locks; returning sooner does not")
    func grace() async {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.defaults.set(60, forKey: DefaultsKey.lockGraceSeconds)
        rig.lock.prepareForLaunch()
        await rig.lock.unlock()
        #expect(!rig.lock.isLocked)

        rig.lock.sceneDidLeave()
        rig.clock.advance(by: 59)
        rig.lock.sceneDidReturn()
        #expect(!rig.lock.isLocked)

        rig.lock.sceneDidLeave()
        rig.clock.advance(by: 61)
        rig.lock.sceneDidReturn()
        #expect(rig.lock.isLocked)
        #expect(rig.keys.status == .locked)
    }

    @Test("The default grace is a minute, and a bad stored value is ignored")
    func graceSetting() {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        #expect(rig.lock.graceSeconds == 60)
        rig.defaults.set(300, forKey: DefaultsKey.lockGraceSeconds)
        #expect(rig.lock.graceSeconds == 300)
        rig.defaults.set(7, forKey: DefaultsKey.lockGraceSeconds)
        #expect(rig.lock.graceSeconds == 60)
    }

    @Test("Lock now locks at once, and signing in with a code opens without a face")
    func lockNowAndSignIn() async throws {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        try rig.keys.prepare(createIfMissing: false)

        rig.lock.lockNow()
        #expect(rig.lock.isLocked)

        rig.lock.openAfterSignIn()
        #expect(!rig.lock.isLocked)
        #expect(rig.biometrics.calls == 0)
    }

    @Test("Leaving while already locked changes nothing")
    func leaveWhileLocked() {
        let rig = makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.lock.prepareForLaunch()
        rig.lock.sceneDidLeave()
        rig.clock.advance(by: 9_999)
        rig.lock.sceneDidReturn()
        #expect(rig.lock.isLocked)
    }
}
