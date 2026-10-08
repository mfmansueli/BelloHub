//
//  PrivacyCover.swift
//  BelloHub
//

import SwiftUI

/// What the app switcher shows instead of her clients: the brand on the page color. Put over everything whenever
/// the scene is not active (docs/06-PRIVACY-SECURITY.md section 5).
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            BrandMark(size: 72)
        }
        .accessibilityHidden(true)
    }
}
