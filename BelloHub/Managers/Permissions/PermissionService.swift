//
//  PermissionService.swift
//  BelloHub
//

import Observation

/// What the app may use on this phone. Onboarding asks through it, and Privacy and security (S10) reads the same
/// answers, so the two never disagree.
@MainActor
@Observable
final class PermissionService {
    private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    private let provider: any PermissionProviding

    init(provider: any PermissionProviding = SystemPermissionProvider()) {
        self.provider = provider
    }

    func status(of kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? .notDetermined
    }

    func refresh() async {
        for kind in PermissionKind.allCases {
            statuses[kind] = await provider.status(of: kind)
        }
    }

    /// Shows the system dialog for `kind` and remembers the answer.
    @discardableResult
    func request(_ kind: PermissionKind) async -> PermissionStatus {
        let answer = await provider.request(kind)
        statuses[kind] = answer
        return answer
    }
}
