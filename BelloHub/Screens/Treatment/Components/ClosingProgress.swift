//
//  ClosingProgress.swift
//  BelloHub
//

import SwiftUI

/// The small "Step n of 4" of a visit's closing (routine-a item 7): the record, photos, aftercare, next visit. The bar
/// speaks as "Step 2 of 4"; the line under it names what comes next is the screen's own title.
struct ClosingProgress: View {
    let step: TreatmentFlowStep

    var body: some View {
        StepProgressBar(current: VisitClosingRules.position(of: step), total: VisitClosingRules.totalSteps)
            .accessibilityIdentifier("treatmentFlow.closing.progress")
    }
}
