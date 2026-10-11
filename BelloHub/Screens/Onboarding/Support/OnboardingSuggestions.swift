//
//  OnboardingSuggestions.swift
//  BelloHub
//

import Foundation

/// What the catalog offers for the professions she chose, and how her selections follow when she changes her mind.
enum OnboardingSuggestions {
    /// Services of every chosen profession, in the order she chose them, each key once.
    static func services(for professions: [ProfessionID], in catalog: ProfessionCatalog) -> [SuggestedService] {
        uniqued(professions.compactMap { catalog.entry(for: $0) }.flatMap(\.services))
    }

    static func tags(for professions: [ProfessionID], in catalog: ProfessionCatalog) -> [SuggestedTag] {
        uniqued(professions.compactMap { catalog.entry(for: $0) }.flatMap(\.tags))
    }

    /// The service a new professional starts with (routine-a item 3): the first preselected service of her first
    /// profession (the catalog's most common one), else its first service.
    static func firstService(for professions: [ProfessionID], in catalog: ProfessionCatalog) -> SuggestedService? {
        guard let first = professions.first, let entry = catalog.entry(for: first) else { return nil }
        return entry.services.first(where: \.selected) ?? entry.services.first
    }

    /// Selection after the professions changed: keeps what she picked if it is still on offer and keeps one first
    /// service (hers while it is still offered, else the new first profession's default). A profession she removed
    /// takes its picks with it; other suggestions are never switched on for her: one service is enough to start.
    static func reconciledServices(
        selected: Set<String>, firstKey: String?, current: [ProfessionID], in catalog: ProfessionCatalog
    ) -> (selected: Set<String>, firstKey: String?) {
        let available = Set(services(for: current, in: catalog).map(\.key))
        var kept = selected.intersection(available)
        let first = firstKey.flatMap { available.contains($0) ? $0 : nil }
            ?? firstService(for: current, in: catalog)?.key
        if let first { kept.insert(first) }
        return (kept, first)
    }

    static func reconciledTagKeys(
        selected: Set<String>, previous: [ProfessionID], current: [ProfessionID], in catalog: ProfessionCatalog
    ) -> Set<String> {
        let available = Set(tags(for: current, in: catalog).map(\.key))
        let added = current.filter { !previous.contains($0) }
        let defaults = Set(tags(for: added, in: catalog).filter(\.selected).map(\.key))
        return selected.intersection(available).union(defaults)
    }

    /// "estheticians and hair stylists", for "Suggested for ...".
    static func pluralNames(for professions: [ProfessionID], in catalog: ProfessionCatalog,
                            formatter: Formatters) -> String {
        formatter.list(professions.compactMap { catalog.entry(for: $0)?.plural })
    }

    private static func uniqued<Element: Identifiable>(_ items: [Element]) -> [Element] where Element.ID == String {
        var seen: Set<String> = []
        return items.filter { seen.insert($0.id).inserted }
    }
}
