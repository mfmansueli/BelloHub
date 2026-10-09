//
//  VaultStorable+TimeBlock.swift
//  BelloHub
//

import Foundation

extension TimeBlock: VaultStorable {
    static var kind: VaultKind { .timeBlock }
    /// The reason is private (docs/05-DATA-MODEL.md); the times stay in the clear to find the blocks of a range.
    static var sensitiveKeys: Set<String> { ["reason"] }

    var index: VaultIndex {
        VaultIndex(dateA: startsAt, dateB: endsAt)
    }
}
