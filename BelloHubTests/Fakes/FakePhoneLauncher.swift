//
//  FakePhoneLauncher.swift
//  BelloHubTests
//

@testable import BelloHub

/// A phone that records the calls it was asked to place and answers whether it could place them.
@MainActor
final class FakePhoneLauncher: PhoneLaunching {
    var canPlaceCalls = true
    private(set) var dialed: [String] = []

    func call(_ phoneE164: String) async -> Bool {
        dialed.append(phoneE164)
        return canPlaceCalls
    }
}
