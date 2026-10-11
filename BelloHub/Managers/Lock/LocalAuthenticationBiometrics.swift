//
//  LocalAuthenticationBiometrics.swift
//  BelloHub
//

import LocalAuthentication

/// `LocalAuthentication` as `BiometricAuthenticating`. Uses the device-owner policy, so a failed face offers the
/// passcode instead of locking her out (docs/06-PRIVACY-SECURITY.md section 5).
struct LocalAuthenticationBiometrics: BiometricAuthenticating {
    var kind: BiometryKind {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcodeOnly
        }
    }

    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }
        do {
            let allowed = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return allowed ? .success : .failed
        } catch let failure as LAError {
            switch failure.code {
            case .userCancel, .systemCancel, .appCancel: return .cancelled
            case .passcodeNotSet, .biometryNotAvailable: return .unavailable
            default: return .failed
            }
        } catch {
            return .failed
        }
    }
}
