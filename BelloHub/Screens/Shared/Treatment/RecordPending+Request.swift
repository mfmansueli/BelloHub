//
//  RecordPending+Request.swift
//  BelloHub
//

import Foundation

extension RecordPending.Item {
    /// The visit form for this item: a draft opens itself, an unwritten booking opens a new record linked to it (or
    /// the one already made, if it was written meanwhile: the flow never makes a second record).
    var flowRequest: TreatmentFlowRequest {
        TreatmentFlowRequest(clientID: clientID, appointmentID: appointmentID, serviceID: serviceID,
                             recordID: recordID)
    }
}
