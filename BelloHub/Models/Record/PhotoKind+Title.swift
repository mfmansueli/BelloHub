//
//  PhotoKind+Title.swift
//  BelloHub
//

import Foundation

extension PhotoKind {
    var title: LocalizedStringResource {
        switch self {
        case .before: "treatmentFlow.photos.before"
        case .after: "treatmentFlow.photos.after"
        case .progress: "treatmentFlow.photos.progress"
        }
    }
}
