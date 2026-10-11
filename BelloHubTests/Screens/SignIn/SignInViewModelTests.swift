//
//  SignInViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("SignInViewModel")
struct SignInViewModelTests {
    private struct Rig {
        let model: SignInViewModel
        let provider: FakeAuthProvider
        let clock: MutableClock
        let signedIn: SignInCounter
        let defaults: UserDefaults
        let suite: String
    }

    @MainActor
    final class SignInCounter {
        var calls = 0
    }

    private func makeRig(region: String = "BR") throws -> Rig {
        let suite = "test.signin.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let provider = FakeAuthProvider()
        let session = SessionService(provider: provider, defaults: defaults)
        let regions = try RegionCatalog.loadBundled()
        let clock = MutableClock()
        let counter = SignInCounter()
        let model = SignInViewModel(
            session: session, catalog: regions, initialRegion: try #require(regions.preset(for: region)),
            now: { clock.now }, onSignedIn: { counter.calls += 1 }
        )
        return Rig(model: model, provider: provider, clock: clock, signedIn: counter, defaults: defaults, suite: suite)
    }

    @Test("A Brazilian number typed the local way is sent in international form")
    func sendsNormalizedNumber() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.model.phoneInput = "(11) 91234-5678"

        await rig.model.sendCodeAsync()

        #expect(rig.provider.requestedPhones == ["+5511912345678"])
        #expect(rig.model.step == .code)
        #expect(rig.model.e164 == "+5511912345678")
        #expect(rig.model.phoneProblem == nil)
    }

    @Test("A number that is too short or empty never reaches the provider")
    func rejectsBadNumbers() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        #expect(!rig.model.canSend)

        rig.model.phoneInput = "123"
        await rig.model.sendCodeAsync()

        #expect(rig.provider.requestedPhones.isEmpty)
        #expect(rig.model.step == .phone)
        #expect(rig.model.phoneProblem != nil)
    }

    @Test("The chosen country changes how a local number is read")
    func region() async throws {
        let rig = try makeRig(region: "PT")
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.model.phoneInput = "912 345 678"
        await rig.model.sendCodeAsync()
        #expect(rig.provider.requestedPhones == ["+351912345678"])
    }

    @Test("A provider error stays on the phone step and is shown")
    func providerError() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.provider.requestError = .network
        rig.model.phoneInput = "11912345678"

        await rig.model.sendCodeAsync()

        #expect(rig.model.step == .phone)
        #expect(rig.model.authError == .network)
        #expect(!rig.model.isWorking)
    }

    @Test("The sixth digit signs in by itself and tells the app")
    func autoVerify() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.model.phoneInput = "11912345678"
        await rig.model.sendCodeAsync()

        rig.model.codeChanged("12345")
        #expect(rig.provider.verifiedCodes.isEmpty)
        rig.model.codeChanged("123 456")

        #expect(await Wait.untilMain { rig.signedIn.calls == 1 })
        #expect(rig.provider.verifiedCodes == ["123456"])
    }

    @Test("A wrong code is explained and cleared so she can type again")
    func wrongCode() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.model.phoneInput = "11912345678"
        await rig.model.sendCodeAsync()
        rig.provider.verifyError = .invalidCode

        rig.model.codeChanged("000000")

        #expect(await Wait.untilMain { rig.model.authError == .invalidCode })
        #expect(rig.model.code.isEmpty)
        #expect(rig.signedIn.calls == 0)
        rig.model.codeChanged("1")
        #expect(rig.model.authError == nil)
    }

    @Test("Resend waits out the countdown, then asks again")
    func resend() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.model.phoneInput = "11912345678"
        await rig.model.sendCodeAsync()
        #expect(rig.model.secondsUntilResend == SignInRules.resendSeconds)

        rig.model.resend()
        #expect(rig.provider.requestedPhones.count == 1)

        rig.clock.advance(by: 31)
        #expect(rig.model.secondsUntilResend == 0)
        rig.model.resend()
        #expect(await Wait.untilMain { rig.provider.requestedPhones.count == 2 })
        #expect(rig.model.secondsUntilResend == SignInRules.resendSeconds)
    }

    @Test("Using a different number goes back and forgets the code")
    func differentNumber() async throws {
        let rig = try makeRig()
        defer { rig.defaults.removePersistentDomain(forName: rig.suite) }
        rig.model.phoneInput = "11912345678"
        await rig.model.sendCodeAsync()
        rig.model.codeChanged("123")

        rig.model.useDifferentNumber()

        #expect(rig.model.step == .phone)
        #expect(rig.model.code.isEmpty)
    }
}
