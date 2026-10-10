//
//  View+UITesting.swift
//  BelloHub
//

import SwiftUI

extension View {
    /// UI tests launch the app with `-uiTesting` so transitions never race the assertions: it removes
    /// SwiftUI's own animations and tells the design system's motion kit to stand still. `-uiDark` also sets the
    /// appearance to dark, for screenshots.
    /// Compiled out of Release builds: test hooks must not ship.
    func disablesAnimationsForUITests() -> some View {
        #if DEBUG
        transaction { transaction in
            if LaunchOptions.current.isUITesting {
                transaction.animation = nil
            }
        }
        .environment(\.isMotionDisabled, LaunchOptions.current.isUITesting)
        .preferredColorScheme(LaunchOptions.current.uiDark ? .dark : nil)
        #else
        self
        #endif
    }
}
