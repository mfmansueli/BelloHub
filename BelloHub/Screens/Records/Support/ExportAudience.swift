//
//  ExportAudience.swift
//  BelloHub
//

import Foundation

/// Who the exported PDF is for. The client's copy never carries the professional's private notes (D2).
enum ExportAudience: String, CaseIterable, Identifiable, Sendable {
    case client
    case healthProfessional

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .client: "exportRecord.audience.client"
        case .healthProfessional: "exportRecord.audience.doctor"
        }
    }
}
