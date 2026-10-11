//
//  FakeClipboard.swift
//  BelloHubTests
//

@testable import BelloHub

/// The clipboard in a test: records what was copied instead of touching the system pasteboard.
@MainActor
final class FakeClipboard: ClipboardWriting {
    private(set) var written: [String] = []

    func write(_ text: String) {
        written.append(text)
    }
}
