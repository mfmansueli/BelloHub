//
//  PhotoVisibility+Title.swift
//  BelloHub
//

import Foundation

extension PhotoVisibility {
    /// Who can see the photo, in the words the picker uses.
    var title: LocalizedStringResource {
        switch self {
        case .professionalOnly: "treatmentFlow.photos.visibility.private"
        case .shareWithClient: "treatmentFlow.photos.visibility.client"
        case .portfolio: "treatmentFlow.photos.visibility.portfolio"
        }
    }
}
