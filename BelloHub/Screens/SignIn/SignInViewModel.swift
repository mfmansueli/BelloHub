//
//  SignInViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The phone and the six-digit code, as two steps of one screen. It never touches an SDK: `SessionService` does.
@MainActor
@Observable
final class SignInViewModel {
    enum Step: Equatable {
        case phone
        case code
    }

    private(set) var step: Step = .phone
    var phoneInput = ""
    var region: RegionPreset
    private(set) var code = ""
    private(set) var isWorking = false
    private(set) var phoneProblem: PhoneNormalizer.Failure?
    private(set) var authError: AuthError?
    private(set) var sentAt: Date?
    private(set) var e164: String?

    let regions: [RegionPreset]
    private let session: SessionService
    private let normalizer: PhoneNormalizer
    private let now: @Sendable () -> Date
    private let onSignedIn: @MainActor () async -> Void

    init(
        session: SessionService,
        catalog: RegionCatalog,
        initialRegion: RegionPreset,
        now: @escaping @Sendable () -> Date = { Date() },
        onSignedIn: @escaping @MainActor () async -> Void
    ) {
        self.session = session
        self.normalizer = PhoneNormalizer(catalog: catalog)
        self.regions = catalog.presetsForPicker
        self.region = initialRegion
        self.now = now
        self.onSignedIn = onSignedIn
    }

    // MARK: - Derived

    var canSend: Bool { !isWorking && !phoneInput.trimmingCharacters(in: .whitespaces).isEmpty }

    var canVerify: Bool { !isWorking && SignInRules.isComplete(code) }

    var secondsUntilResend: Int { SignInRules.secondsUntilResend(sentAt: sentAt, now: now()) }

    // MARK: - Phone step

    /// Fire-and-forget entry point for the button (CLAUDE.md section 2).
    func sendCode() {
        Task { await sendCodeAsync() }
    }

    func sendCodeAsync() async {
        guard !isWorking else { return }
        phoneProblem = nil
        authError = nil
        switch normalizer.normalize(phoneInput, defaultRegion: region) {
        case .failure(let failure):
            phoneProblem = failure
        case .success(let number):
            isWorking = true
            defer { isWorking = false }
            do {
                try await session.requestCode(phoneE164: number)
                e164 = number
                sentAt = now()
                code = ""
                step = .code
            } catch let error as AuthError {
                authError = error
            } catch {
                authError = .network
            }
        }
    }

    func useDifferentNumber() {
        step = .phone
        code = ""
        authError = nil
        phoneProblem = nil
    }

    // MARK: - Code step

    /// Called when the code field changes; signs in by itself when the sixth digit arrives.
    func codeChanged(_ raw: String) {
        let cleaned = SignInRules.sanitizedCode(raw)
        code = cleaned
        authError = nil
        if SignInRules.isComplete(cleaned) { verify() }
    }

    func verify() {
        Task { await verifyAsync() }
    }

    func verifyAsync() async {
        guard canVerify else { return }
        isWorking = true
        authError = nil
        do {
            try await session.verify(code: code)
            isWorking = false
            await onSignedIn()
        } catch let error as AuthError {
            isWorking = false
            authError = error
            if error == .invalidCode { code = "" }
        } catch {
            isWorking = false
            authError = .network
        }
    }

    func resend() {
        guard secondsUntilResend == 0, let e164 else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await session.requestCode(phoneE164: e164)
                sentAt = now()
                authError = nil
            } catch let error as AuthError {
                authError = error
            } catch {
                authError = .network
            }
        }
    }
}
