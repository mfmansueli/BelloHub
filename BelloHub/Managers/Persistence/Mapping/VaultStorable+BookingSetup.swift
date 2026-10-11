//
//  VaultStorable+BookingSetup.swift
//  BelloHub
//

import Foundation

// How the booking setup is stored (S5). None of it is sensitive: availability, page switches, policies and her own
// message wording hold no client data (docs/05-DATA-MODEL.md section 1), so there is nothing to seal.

extension AvailabilityDocument: VaultStorable {
    static var kind: VaultKind { .availability }

    var index: VaultIndex {
        VaultIndex(dateA: updatedAt)
    }
}

extension BookingSetup: VaultStorable {
    static var kind: VaultKind { .bookingSetup }

    var index: VaultIndex {
        VaultIndex(dateA: updatedAt, textKey: slug)
    }
}

extension QuickReply: VaultStorable {
    static var kind: VaultKind { .quickReply }

    var index: VaultIndex {
        VaultIndex(dateA: updatedAt, textKey: title)
    }
}
