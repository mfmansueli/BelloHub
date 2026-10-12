//
//  RecordDestinations.swift
//  BelloHub
//

import SwiftUI

extension View {
    /// Maps every `RecordRoute` to its screen. Put it on the root of a `NavigationStack`.
    func recordDestinations() -> some View {
        navigationDestination(for: RecordRoute.self) { route in
            switch route {
            case .history(let clientID): RecordHistoryView(clientID: clientID)
            case .visit(let recordID): VisitDetailView(recordID: recordID)
            }
        }
    }

    /// Presents the sheet a `RecordSheet` names.
    func recordSheet(item: Binding<RecordSheet?>) -> some View {
        sheet(item: item) { sheet in
            switch sheet {
            case .incident(let clientID, let appointmentID, let recordID):
                IncidentView(clientID: clientID, appointmentID: appointmentID, recordID: recordID)
            case .exportRecord(let clientID): ExportRecordView(clientID: clientID)
            case .organizePhotos(let clientID): OrganizePhotosView(clientID: clientID)
            }
        }
    }

    /// Presents the treatment flow full screen.
    func treatmentFlow(item: Binding<TreatmentFlowRequest?>) -> some View {
        fullScreenCover(item: item) { request in TreatmentFlowView(request: request) }
    }
}
