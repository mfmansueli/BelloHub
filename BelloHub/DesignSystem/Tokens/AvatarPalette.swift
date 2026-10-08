//
//  AvatarPalette.swift
//  BelloHub
//

import SwiftUI

/// The four wash pairs of an avatar. The pair is chosen by a stable hash of the id, so a person keeps
/// the same color across launches and devices.
enum AvatarPalette: Int, CaseIterable {
    case rose
    case sage
    case sand
    case peach

    var start: Color {
        switch self {
        case .rose: Color(light: 0xF6E4E8, dark: 0x4A343A)
        case .sage: Color(light: 0xE6ECE0, dark: 0x30402C)
        case .sand: Color(light: 0xF3E7DA, dark: 0x3A322B)
        case .peach: Color(light: 0xFBE9DD, dark: 0x40291F)
        }
    }

    var end: Color {
        switch self {
        case .rose: Color(light: 0xE8C6CF, dark: 0x5A4047)
        case .sage: Color(light: 0xC9D6C0, dark: 0x3D5037)
        case .sand: Color(light: 0xE2CDB6, dark: 0x4A4036)
        case .peach: Color(light: 0xEDC7B2, dark: 0x52352A)
        }
    }

    /// Initials color. Darker than the prototype's for sage and peach, whose initials were 4.0:1
    /// on the end of the gradient.
    var text: Color {
        switch self {
        case .rose: Color(light: 0x74404F, dark: 0xF2C4D0, lightIncreased: 0x5E3342, darkIncreased: 0xFADDE5)
        case .sage: Color(light: 0x46573F, dark: 0xD0DEC6, lightIncreased: 0x3F4F39, darkIncreased: 0xE2EEDA)
        case .sand: Color(light: 0x4A4036, dark: 0xE2D6C8, lightIncreased: 0x2F2822, darkIncreased: 0xF0E6DA)
        case .peach: Color(light: 0x74432C, dark: 0xEBBFA9, lightIncreased: 0x6B3D27, darkIncreased: 0xF3D0BC)
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
