//
//  Text+Prompt.swift
//  BelloHub
//

import SwiftUI

extension Text {
    /// The placeholder of a text field. The system's own placeholder gray is about 2:1 on the field's fill, so every
    /// prompt is drawn with `ink2` (4.5:1 or better) instead (CLAUDE.md section 5).
    static func prompt(_ key: LocalizedStringKey) -> Text {
        Text(key).foregroundStyle(Palette.ink2)
    }
}
