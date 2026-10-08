//
//  Avatar.swift
//  BelloHub
//

import SwiftUI

/// A circle with a gradient pair chosen by a stable hash of `id`, the initials in the pair's deep
/// color and a 1.5 pt inner ring. Shows `photo` instead when there is one. Decorative: the row that
/// holds it carries the spoken name, so the avatar is hidden from VoiceOver.
struct Avatar: View {
    let name: String
    let id: String
    var size: CGFloat = 44
    var photo: Image?
    @Environment(\.locale) private var locale

    var body: some View {
        let pair = AvatarPalette.pair(for: id)
        ZStack {
            Circle().fill(LinearGradient(
                colors: [pair.start, pair.end], startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            if let photo {
                photo.resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(verbatim: Initials.make(from: name, locale: locale))
                    .font(initialsFont)
                    .foregroundStyle(pair.text)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5).padding(1.5) }
        .accessibilityHidden(true)
    }

    private var initialsFont: Font {
        .custom(FontRegistry.sansFamily, size: size * 0.34, relativeTo: .subheadline).weight(.semibold)
    }
}
