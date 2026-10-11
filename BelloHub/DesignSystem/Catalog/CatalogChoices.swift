//
//  CatalogChoices.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Appearance the catalog previews, independent of the system setting.
enum CatalogAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Dynamic Type sizes the catalog previews, from the smallest to the largest accessibility size.
enum CatalogTextSize: String, CaseIterable, Identifiable {
    case small
    case standard
    case large
    case accessibility3
    case accessibility5

    var id: String { rawValue }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .small
        case .standard: .large
        case .large: .xxxLarge
        case .accessibility3: .accessibility3
        case .accessibility5: .accessibility5
        }
    }
}
#endif
