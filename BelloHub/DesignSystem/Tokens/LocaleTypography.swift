//
//  LocaleTypography.swift
//  BelloHub
//

import SwiftUI

private struct LocaleTypographyModifier: ViewModifier {
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        // `lineSpacing` travels down the environment, so one call at the root covers every `Text` below.
        // The extra is sized for body text (17 pt); Arabic and Hindi fall back to system fonts that are taller
        // than Fraunces and DM Sans (docs/07-LOCALIZATION.md section 2.5).
        content.lineSpacing(Typography.lineSpacing(forSize: 17, language: locale.language))
    }
}

extension View {
    /// Adds the extra line height Arabic and Hindi need. Apply once at the root of the app (and of the catalog),
    /// after the locale is set.
    func belloLocaleTypography() -> some View {
        modifier(LocaleTypographyModifier())
    }
}
