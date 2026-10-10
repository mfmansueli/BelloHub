//
//  AvatarPalette.swift
//  BelloHub
//

import SwiftUI

/// The four gradient pairs of an avatar: a soft start and the approved brand card fill as the end (sand has no card
/// fill, so it keeps its own). The pair is chosen by a stable hash of the id, so a person keeps
/// the same color across launches and devices.
enum AvatarPalette: Int, CaseIterable {
    case rose
    case sage
    case sand
    case peach

    var start: Color {
        switch self {
        case .rose: Color(light: 0xF5E4EB, dark: 0x573645)
        case .sage: Color(light: 0xE4ECDE, dark: 0x34493A)
        case .sand: Color(light: 0xF2EADD, dark: 0x3E3A33)
        case .peach: Color(light: 0xFAE7DA, dark: 0x5E3F2F)
        }
    }

    var end: Color {
        switch self {
        case .rose: Color(light: 0xE3B5C7, dark: 0x684353)
        case .sage: Color(light: 0xBDD0B3, dark: 0x3B5540)
        case .sand: Color(light: 0xDDCBB4, dark: 0x4A443B)
        case .peach: Color(light: 0xF0C5A6, dark: 0x704B37)
        }
    }

    /// Initials color: the deep family accent, 4.5:1 or more on both ends of the gradient in every appearance.
    var text: Color {
        switch self {
        case .rose: Color(light: 0x74374F, dark: 0xF7D3E0, lightIncreased: 0x5E2C40, darkIncreased: 0xFDE3EC)
        case .sage: Color(light: 0x3C5638, dark: 0xDCEBD0, lightIncreased: 0x2E442B, darkIncreased: 0xEAF4E0)
        case .sand: Color(light: 0x4A4036, dark: 0xEDE3D6, lightIncreased: 0x2F2822, darkIncreased: 0xF6EEE4)
        case .peach: Color(light: 0x70402A, dark: 0xFFE2CC, lightIncreased: 0x5C331F, darkIncreased: 0xFFEEDE)
        }
    }

    /// FNV-1a over the UTF-8 bytes. `hashValue` is seeded per process, so it cannot be used here.
    static func pair(for id: String) -> AvatarPalette {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return allCases[Int(hash % UInt64(allCases.count))]
    }
}
