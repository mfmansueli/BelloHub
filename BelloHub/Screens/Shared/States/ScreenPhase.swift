//
//  ScreenPhase.swift
//  BelloHub
//

import Foundation

/// Which of the four states (7.11) a screen that loads data is in. A ViewModel works it out from its own flags, in one
/// place, so a screen never shows two states at once.
enum ScreenPhase: Equatable, Sendable {
    /// The data has not arrived yet.
    case loading
    /// The data arrived and there is nothing to show.
    case empty
    /// The read failed; the text says what happened and how to fix it.
    case failed(String)
    case content

    /// `failed` wins over `loading`, and `loading` over `empty`: an empty list is only known once the read finished.
    static func resolve(isLoading: Bool, errorMessage: String?, isEmpty: Bool) -> ScreenPhase {
        if let errorMessage { return .failed(errorMessage) }
        if isLoading { return .loading }
        return isEmpty ? .empty : .content
    }
}
