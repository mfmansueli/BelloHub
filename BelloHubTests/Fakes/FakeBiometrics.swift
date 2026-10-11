//
//  FakeBiometrics.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// A Face ID that answers from a script: each call takes the next result, and the last one repeats.
final class FakeBiometrics: BiometricAuthenticating, Sendable {
    let kind: BiometryKind
    private let results: OSAllocatedUnfairLock<[BiometricResult]>
    private let callCount = OSAllocatedUnfairLock(initialState: 0)

    init(_ results: [BiometricResult], kind: BiometryKind = .faceID) {
        self.kind = kind
        self.results = OSAllocatedUnfairLock(initialState: results)
    }

    var calls: Int { callCount.withLock { $0 } }

    func authenticate(reason: String) async -> BiometricResult {
        callCount.withLock { $0 += 1 }
        return results.withLock { queue in
            queue.count > 1 ? queue.removeFirst() : (queue.first ?? .failed)
        }
    }
}
