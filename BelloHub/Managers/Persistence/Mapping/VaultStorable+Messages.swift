//
//  VaultStorable+Messages.swift
//  BelloHub
//

import Foundation

// The message log holds the template kind and a time, never the text, so nothing is sealed (docs/05 section 1).
extension MessageLog: VaultStorable {
    static var kind: VaultKind { .messageLog }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, dateA: openedAt, textKey: template, statusRaw: channel.rawValue)
    }
}
