//
//  HealthDebugRoute.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// `-uiRoute health` and `-uiRoute formTemplates`: shows one of the two screens directly, in its own navigation stack,
/// so a UI test can drive it before the tab that pushes it is wired in. DEBUG only; it never ships.
struct HealthDebugRoute: View {
    let route: String

    var body: some View {
        NavigationStack {
            switch route {
            case "formTemplates": FormTemplatesView()
            default: ClientHealthView(clientID: UITestSeeding.healthClientID)
            }
        }
    }
}
#endif
