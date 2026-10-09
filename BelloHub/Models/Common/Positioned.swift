//
//  Positioned.swift
//  BelloHub
//

/// A value in a list she can reorder by hand. Its `position` is what the vault sorts by, so a drag has to rewrite it.
protocol Positioned: Identifiable, Equatable, Sendable {
    var position: Int { get set }
}
