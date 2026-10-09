//
//  ClientSource+Title.swift
//  BelloHub
//

import SwiftUI

extension ClientSource {
    /// How the client found her, in the reader's language.
    var title: LocalizedStringKey {
        switch self {
        case .bookingLink: "clientProfile.source.bookingLink"
        case .importedClients: "clientProfile.source.import"
        case .manual: "clientProfile.source.manual"
        case .referral: "clientProfile.source.referral"
        }
    }
}
