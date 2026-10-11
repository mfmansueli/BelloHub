//
//  RecordStatus+Title.swift
//  BelloHub
//

import Foundation

extension RecordStatus {
    var title: LocalizedStringResource {
        switch self {
        case .draft: "record.status.draft"
        case .finalized: "record.status.finalized"
        }
    }
}
