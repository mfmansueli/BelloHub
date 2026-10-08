//
//  RenderedLegalText.swift
//  BelloHub
//

/// A legal text ready to draw: its title and its blocks, with every placeholder filled.
struct RenderedLegalText: Hashable, Sendable {
    let title: String
    let blocks: [LegalTextBlock]
}
