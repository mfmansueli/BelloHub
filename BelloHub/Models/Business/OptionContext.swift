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

    static let fallback = OptionContext.technique

    var id: String { rawValue }
}
