//
//  ExportSnapshot.swift
//  BelloHub
//

import Foundation

/// Everything the export reads from the vault, in plain structs, so the builder is pure and tested from fixtures.
struct ExportSnapshot: Sendable {
    var profile: ProfessionalProfile?
    var clients: [Client] = []
    var tags: [Tag] = []
    var services: [Service] = []
    var appointments: [Appointment] = []
    var records: [TreatmentRecord] = []
    var photos: [(photo: Photo, data: PhotoData)] = []
}
