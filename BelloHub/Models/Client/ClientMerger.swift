//
//  ClientMerger.swift
//  BelloHub
//

import Foundation

/// What two profiles of the same person become when she merges them. Pure: the repositories call it inside the
/// merge, so both implementations combine the client values the same way, and the merge screen can preview it.
///
/// The rule is "the kept profile wins, the merged one fills the gaps": a single value (phone, email, birthday) stays
/// the kept profile's unless it has none; lists and tags are joined without repeating an entry; the two private
/// notes are joined into one paragraph each, or kept as one when one says what the other says. Anything that protects
/// the client wins: booking stays stopped and reminders stay off if either profile had them that way.
enum ClientMerger {
    static func merged(keeping kept: Client, merging other: Client) -> Client {
        var result = kept
        result.phoneE164 = kept.phoneE164 ?? other.phoneE164
        result.email = kept.email ?? other.email
        result.birthday = kept.birthday ?? other.birthday
        result.tagIDs = union(kept.tagIDs, other.tagIDs)
        result.noShowCountResetAt = kept.noShowCountResetAt ?? other.noShowCountResetAt
        result.createdAt = min(kept.createdAt, other.createdAt)
        // Merging an active profile into an archived one brings her back: she is still a client.
        result.isArchived = kept.isArchived && other.isArchived
        result.onlineBookingStopped = kept.onlineBookingStopped || other.onlineBookingStopped
        result.remindersEnabled = kept.remindersEnabled && other.remindersEnabled
        result.importantNote = note(kept.importantNote, other.importantNote)
        result.stopReason = result.onlineBookingStopped ? note(kept.stopReason, other.stopReason) : nil
        result.allergies = union(kept.allergies, other.allergies)
        result.sensitivities = union(kept.sensitivities, other.sensitivities)
        result.preferences = union(kept.preferences, other.preferences)
        result.recurringRequests = union(kept.recurringRequests, other.recurringRequests)
        return result
    }

    // MARK: - Lists

    /// `first` followed by what `second` has that `first` does not, in order. Entries are trimmed and compared without
    /// regard to case, accents or width, so "Fragrance-free" and "fragrance-free " are one entry; the first spelling
    /// stays.
    static func union(_ first: [String], _ second: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in first + second {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(comparisonKey(trimmed)).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    static func union(_ first: [UUID], _ second: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return (first + second).filter { seen.insert($0).inserted }
    }

    // MARK: - Notes

    /// Two private notes as one. Blank notes disappear, a note that says the same as the other (or contains it) is
    /// not repeated, and two different notes are kept as two paragraphs, the kept profile's first.
    static func note(_ first: String?, _ second: String?) -> String? {
        let one = first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let two = second?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if one.isEmpty { return two.isEmpty ? nil : two }
        if two.isEmpty { return one }
        let oneKey = comparisonKey(one)
        let twoKey = comparisonKey(two)
        if oneKey.contains(twoKey) { return one }
        if twoKey.contains(oneKey) { return two }
        return "\(one)\n\n\(two)"
    }

    /// How two entries are compared for "the same": without regard to case, accents or width.
    static func comparisonKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
