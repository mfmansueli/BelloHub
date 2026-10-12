//
//  OptionContext.swift
//  BelloHub
//

import Foundation

/// Where a saved option belongs, so each list keeps its own words: a technique never shows among preferences.
/// Products live in her product list (`Product`) and the choices of her own fields live in her record template; these
/// are the descriptive lists that had no home of their own. Fixed states (statuses, permissions, severities) are never
/// options she can create.
enum OptionContext: String, PersistedEnum, Identifiable {
    case technique
    case preference
    case sensitivity
    case recurringRequest
    /// How a client reacted, in her words, offered on every visit's reaction field next to her profession's answers.
    case reaction
    /// Aftercare she gives, offered on the aftercare field next to her profession's answers.
    case aftercare

    static let fallback = OptionContext.technique

    var id: String { rawValue }
}
