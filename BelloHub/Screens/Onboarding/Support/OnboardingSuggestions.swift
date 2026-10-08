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

    /// Selection after the professions changed: keeps what she picked if it is still on offer and adds the
    /// preselected services of a profession she just added. A profession she removed takes its picks with it.
    static func reconciledServiceKeys(
        selected: Set<String>, previous: [ProfessionID], current: [ProfessionID], in catalog: ProfessionCatalog
    ) -> Set<String> {
        let available = Set(services(for: current, in: catalog).map(\.key))
        let added = current.filter { !previous.contains($0) }
        let defaults = Set(services(for: added, in: catalog).filter(\.selected).map(\.key))
        return selected.intersection(available).union(defaults)
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
