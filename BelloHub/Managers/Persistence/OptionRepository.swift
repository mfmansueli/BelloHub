//
//  OptionRepository.swift
//  BelloHub
//

import Foundation

/// The options she saved to reuse (techniques, preferences…). Never deleted: an option is archived, so nothing she
/// wrote with it ever loses its meaning.
protocol OptionRepository: Sendable {
    func savedOptions() async throws -> [SavedOption]
    func save(_ option: SavedOption) async throws
    /// Stores several options together: a reorder renumbers many of them at once.
    func save(_ options: [SavedOption]) async throws
}
