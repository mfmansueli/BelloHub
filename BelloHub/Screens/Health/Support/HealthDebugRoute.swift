//
//  HealthDebugRoute.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// `-uiRoute health`, `formTemplates` and `treatmentFlow`: shows one of the screens directly, in its own stack,
/// so a UI test can drive it before the tab that pushes it is wired in. DEBUG only; it never ships.
struct HealthDebugRoute: View {
    let route: String

    var body: some View {
        if route == "treatmentFlow" {
            // The flow brings its own navigation stack, like when it is presented full screen.
            TreatmentFlowView(request: TreatmentFlowRequest(clientID: UITestSeeding.healthClientID))
        } else {
            NavigationStack {
                switch route {
                case "formTemplates": FormTemplatesView()
                default: ClientHealthView(clientID: UITestSeeding.healthClientID)
                }
            }
        }
    }
}
#endif
