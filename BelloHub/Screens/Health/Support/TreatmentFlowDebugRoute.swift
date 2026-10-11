//
//  TreatmentFlowDebugRoute.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// `-uiRoute treatmentFlow`: presents the treatment flow full screen over an empty page, as the app does, so a UI test
/// can see it close ("Done", "Finish later"). DEBUG only; it never ships.
struct TreatmentFlowDebugRoute: View {
    @State private var request: TreatmentFlowRequest? = TreatmentFlowRequest(clientID: UITestSeeding.healthClientID)

    var body: some View {
        Palette.bg
            .ignoresSafeArea()
            .overlay {
                Text(verbatim: "Flow closed")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("treatmentFlow.debug.closed")
            }
            .treatmentFlow(item: $request)
    }
}
#endif
