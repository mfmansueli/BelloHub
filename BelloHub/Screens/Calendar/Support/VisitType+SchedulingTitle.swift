//
//  VisitType+SchedulingTitle.swift
//  BelloHub
//

import Foundation

extension VisitType {
    /// The words of the visit-type chips in New appointment. Look it up with `.localized(in:)`.
    var schedulingTitle: LocalizedStringResource {
        switch self {
        case .treatment: LocalizedStringResource("newAppointment.visitType.treatment", defaultValue: "New treatment")
        case .touchUp: LocalizedStringResource("newAppointment.visitType.touchUp", defaultValue: "Touch-up")
        case .reactionCheck:
            LocalizedStringResource("newAppointment.visitType.reactionCheck", defaultValue: "Check after a reaction")
        }
    }
}
