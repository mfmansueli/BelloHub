//
//  Typography.swift
//  BelloHub
//

import SwiftUI

/// System text styles scale with Dynamic Type on their own. When a brand font is chosen it joins
/// these tokens through `Font.custom(_:size:relativeTo:)` so the scaling is preserved.
enum Typography {
    static let title = Font.system(.title, weight: .semibold)
    static let body = Font.system(.body)
    static let caption = Font.system(.caption)
}
