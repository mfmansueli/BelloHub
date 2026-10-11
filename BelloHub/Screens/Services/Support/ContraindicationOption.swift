//
//  ContraindicationOption.swift
//  BelloHub
//

/// One thing she can mark as "not suitable if the client has", in the picker.
struct ContraindicationOption: Identifiable, Hashable, Sendable {
    /// What the service stores (`pregnancy`, `allergies.latex`, `minor`): the key the matcher understands.
    let token: String
    /// The row in the picker, inside its group: "Latex".
    let title: String
    /// The chip on the service form, where the group is not on screen: "Allergies · Latex".
    let summary: String

    var id: String { token }
}
