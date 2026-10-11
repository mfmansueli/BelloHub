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

    /// The case names are the palette families (`rose` is the orange, `sage` the green, `peach` the slate, `sand` a
    /// neutral grey); see `Palette`.
    var start: Color {
        switch self {
        case .rose: Color(light: 0xFFE8DC, dark: 0x4A2312)
        case .sage: Color(light: 0xE3F2E8, dark: 0x1C3324)
        case .sand: Color(light: 0xEDEDEB, dark: 0x2C2C2C)
        case .peach: Color(light: 0xE8EAF0, dark: 0x262A3A)
        }
    }

    var end: Color {
        switch self {
        case .rose: Color(light: 0xFFC4A8, dark: 0x6A2E14)
        case .sage: Color(light: 0xC9E8D3, dark: 0x1F4A30)
        case .sand: Color(light: 0xD3D3D0, dark: 0x3A3A3A)
        case .peach: Color(light: 0xD3D8E6, dark: 0x2A3045)
        }
    }

    /// Initials color: the deep family accent, 4.5:1 or more on both ends of the gradient in every appearance.
    var text: Color {
        switch self {
        case .rose: Color(light: 0x8A2E08, dark: 0xFFD3BF, lightIncreased: 0x6E2406, darkIncreased: 0xFFE4D6)
        case .sage: Color(light: 0x1F5A33, dark: 0xC2EBD0, lightIncreased: 0x164426, darkIncreased: 0xDDF5E5)
        case .sand: Color(light: 0x2E2E2C, dark: 0xEDEDEB, lightIncreased: 0x1A1A19, darkIncreased: 0xFFFFFF)
        case .peach: Color(light: 0x343A52, dark: 0xD4D9EE, lightIncreased: 0x252A3D, darkIncreased: 0xE8EBF7)
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
