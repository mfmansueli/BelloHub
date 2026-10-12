//
//  ClientRecordSection.swift
//  BelloHub
//

import Foundation

/// The four parts of a client's record, switched inside the screen. History is first and open by default: it is the
/// reason she opens a record.
enum ClientRecordSection: String, CaseIterable, Identifiable, Sendable {
    case history
    case photos
    case info
    case documents

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .history: "clientRecord.section.history"
        case .photos: "clientRecord.section.photos"
        case .info: "clientRecord.section.info"
        case .documents: "clientRecord.section.documents"
        }
    }
}
