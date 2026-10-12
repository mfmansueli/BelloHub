//
//  QuickAccessViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The quick access sheet's one piece of state: copying her booking link, with "Copied" for a moment after. Opening a
/// screen is navigation and stays in the View.
@MainActor
@Observable
final class QuickAccessViewModel {
    private(set) var copiedLink = false

    private let clipboard: any ClipboardWriting
    private let copiedDuration: Duration
    private var copiedTask: Task<Void, Never>?

    init(clipboard: any ClipboardWriting = SystemClipboard(), copiedDuration: Duration = .seconds(2)) {
        self.clipboard = clipboard
        self.copiedDuration = copiedDuration
    }

    // MARK: - Link

    /// Puts the full address on the clipboard, ready to paste in a chat or a bio.
    func copy(_ link: BookingLink) {
        clipboard.write(link.url.absoluteString)
        copiedLink = true
        copiedTask?.cancel()
        copiedTask = Task { [copiedDuration] in
            try? await Task.sleep(for: copiedDuration)
            guard !Task.isCancelled else { return }
            copiedLink = false
        }
    }
}
