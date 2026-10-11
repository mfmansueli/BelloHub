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

extension KeyManager: InboxKeyOpening {
    /// How many generations back an envelope may be addressed to. Rotation is not in v1, so this is the current one
    /// plus a margin for the day it arrives.
    static let inboxKeyGenerations = 1...4

    func inboxPrivateKey(forKeyID keyId: String) throws -> Curve25519.KeyAgreement.PrivateKey? {
        for generation in Self.inboxKeyGenerations {
            let key = try inboxPrivateKey(generation: generation)
            if KeyDerivation.keyID(forPublicKey: key.publicKey.rawRepresentation) == keyId { return key }
        }
        return nil
    }
}
