//
//  VaultStorable.swift
//  BelloHub
//

import Foundation

/// A domain value the vault can store. The repository maps it to a `VaultItem`: index columns in the clear, the
/// non-sensitive JSON in the clear, and the fields named in `sensitiveKeys` sealed with `VaultFieldCodec`.
protocol VaultStorable: Identifiable, Codable, Sendable where ID == UUID {
    static var kind: VaultKind { get }
    /// Property names that are encrypted at rest. Tests pin these lists against docs/05-DATA-MODEL.md section 1.
    static var sensitiveKeys: Set<String> { get }
    var index: VaultIndex { get }
}

extension VaultStorable {
    static var sensitiveKeys: Set<String> { [] }
}
