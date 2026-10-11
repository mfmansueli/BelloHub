//
//  FakePermissionProvider.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// Permission answers from a table, so a test never shows a system dialog.
final class FakePermissionProvider: PermissionProviding, Sendable {
    private let answers: [PermissionKind: PermissionStatus]
    private let requests = OSAllocatedUnfairLock<[PermissionKind]>(initialState: [])

    init(answers: [PermissionKind: PermissionStatus] = [:]) {
        self.answers = answers
    }

    var requested: [PermissionKind] { requests.withLock { $0 } }

    func status(of kind: PermissionKind) async -> PermissionStatus {
        .notDetermined
    }

    func request(_ kind: PermissionKind) async -> PermissionStatus {
        requests.withLock { $0.append(kind) }
        return answers[kind] ?? .granted
    }
}
