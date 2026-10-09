//
//  KeyManager+InboxKey.swift
//  BelloHub
//

import CryptoKit

extension KeyManager: InboxKeyProviding {
    /// Generation 1 until a rotation UI exists (docs/06 section 4.3: v1 has the model and tests only).
    func currentInboxPublicKey() throws -> InboxPublicKey {
        InboxPublicKey(publicKey: try inboxPrivateKey(generation: 1).publicKey)
    }
}
