//
//  ImportPlan.swift
//  BelloHub
//

import Foundation

/// What confirming an import will do, said before she confirms it (D42, routine item 9): how many of the chosen people
/// are new after deduplication, how many are already in her list, how many free registrations are left, how many go
/// through now and how many wait for a plan. Pure, and the only owner of this preview rule.
///
/// It applies the gate's own rules, so the preview and the result agree: deduplication is
/// `ClientDuplicateRules.partition` (the same call `ClientRegistrationService.importClients` makes) and the free
/// allowance is `RegistrationQuota.decision` through `RegistrationUsage`. The gate takes the new clients in list order,
/// so the first `registeredNow` new ones are saved and the rest are **not saved and not charged**: they wait until she
/// has a plan and imports them again (duplicates are skipped then, so nobody is registered twice).
///
/// When the existing clients could not be read (`existing == nil`) the plan counts every chosen row as new: an upper
/// bound, flagged with `checkedDuplicates == false` so the screen can say so.
struct ImportPlan: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Nothing is chosen.
        case nothingChosen
        /// Everyone chosen is already in her list: nothing will be registered.
        case nothingNew
        /// Every new client fits in the free registrations.
        case allFree
        /// Some go through now; the rest wait for a plan.
        case partlyFree
        /// The free registrations are used: nobody new goes through without a plan.
        case needsPlan
        /// She has a plan: registrations are unlimited.
        case unlimited
    }

    /// The people chosen, valid rows only.
    let chosen: Int
    /// Chosen people that are new after deduplication (against her list and earlier rows).
    let newClients: Int
    /// Chosen people already in her list (or repeated in the batch): skipped, never counted.
    let alreadyInList: Int
    /// Free registrations left before this import.
    let freeLeft: Int
    /// New clients that will be registered now.
    let registeredNow: Int
    /// New clients the free registrations do not cover: not saved, waiting for a plan.
    let waiting: Int
    /// Free registrations left after this import.
    let freeLeftAfter: Int
    let isUnlimited: Bool
    /// False when her list could not be read, so duplicates were not checked and `newClients` is an upper bound.
    let checkedDuplicates: Bool

    init(chosen clients: [Client], existing: [Client]?, usage: RegistrationUsage) {
        let fresh: [Client]
        let duplicates: [Client]
        if let existing {
            (fresh, duplicates) = ClientDuplicateRules.partition(clients, existing: existing)
        } else {
            (fresh, duplicates) = (clients, [])
        }
        chosen = clients.count
        newClients = fresh.count
        alreadyInList = duplicates.count
        isUnlimited = usage.isUnlimited
        freeLeft = usage.remainingFree
        registeredNow = usage.isUnlimited ? fresh.count : min(fresh.count, usage.remainingFree)
        waiting = fresh.count - registeredNow
        freeLeftAfter = usage.isUnlimited ? usage.remainingFree : usage.remainingFree - registeredNow
        checkedDuplicates = existing != nil
    }

    var kind: Kind {
        if chosen == 0 { return .nothingChosen }
        if newClients == 0 { return .nothingNew }
        if isUnlimited { return .unlimited }
        if waiting == 0 { return .allFree }
        return registeredNow > 0 ? .partlyFree : .needsPlan
    }

    /// Whether some of the chosen people need Bello Hub Pro to be registered.
    var needsPlan: Bool { waiting > 0 }

    // MARK: - Trying a small group

    /// The sizes offered for "Try a small group".
    static let trialSizes = [3, 5, 10]

    /// The first `size` rows of `entries` (in list order) whose client is new: rows already in her list are passed
    /// over, so trying 5 registers 5 when there are 5 new ones. Returns the entry ids to select.
    static func trialSelection(size: Int, from entries: [ImportEntry], existing: [Client]?) -> Set<String> {
        guard size > 0 else { return [] }
        let ready = entries.compactMap { entry in entry.client.map { (entry.id, $0) } }
        let freshIDs: Set<UUID>
        if let existing {
            freshIDs = Set(ClientDuplicateRules.partition(ready.map(\.1), existing: existing).fresh.map(\.id))
        } else {
            freshIDs = Set(ready.map(\.1.id))
        }
        return Set(ready.filter { freshIDs.contains($0.1.id) }.prefix(size).map(\.0))
    }

    /// The trial sizes worth offering for a list of `newCount` new clients with `freeLeft` free registrations: the
    /// standard sizes smaller than the list, plus "as many as are free" when that is a different, useful number.
    static func trialChoices(newCount: Int, freeLeft: Int, isUnlimited: Bool) -> [Int] {
        var sizes = trialSizes.filter { $0 < newCount }
        if !isUnlimited, freeLeft > 0, freeLeft < newCount, !sizes.contains(freeLeft) {
            sizes.append(freeLeft)
        }
        return sizes.sorted()
    }
}
