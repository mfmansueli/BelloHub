//
//  View+UITesting.swift
//  BelloHub
//

import SwiftUI

extension View {
    /// UI tests launch the app with `-uiTesting` so transitions never race the assertions.
    /// Compiled out of Release builds: test hooks must not ship.
    func disablesAnimationsForUITests() -> some View {
        #if DEBUG
        transaction { transaction in
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                transaction.animation = nil
            }
        }
        #else
        self
        #endif
    }
}
