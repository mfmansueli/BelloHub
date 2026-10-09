//
//  View+FixedAvatarText.swift
//  BelloHub
//

import SwiftUI

extension View {
    /// Keeps an `Avatar` as it is drawn at the standard text size. The avatar is a decorative circle of a fixed size
    /// and its initials scale with Dynamic Type, so at the accessibility sizes the letters outgrow the circle. The
    /// names and dates next to it do scale, which is what the reader needs; VoiceOver skips the avatar anyway.
    func fixedAvatarText() -> some View {
        dynamicTypeSize(.large)
    }
}
