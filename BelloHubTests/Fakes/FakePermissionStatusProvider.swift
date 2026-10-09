//
//  FakePermissionStatusProvider.swift
//  BelloHubTests
//

@testable import BelloHub

/// A system that always reports the same status for every permission, and answers a request with the same status.
/// (`FakePermissionProvider` reports "not asked yet" until a request is made.)
struct FakePermissionStatusProvider: PermissionProviding {
    let status: PermissionStatus

    func status(of kind: PermissionKind) async -> PermissionStatus { status }

    func request(_ kind: PermissionKind) async -> PermissionStatus { status }
}
