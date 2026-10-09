//
//  EnvelopeOpener.swift
//  BelloHub
//

import CryptoKit
import Foundation

/// Opens a sealed envelope with CryptoKit's HPKE, exactly as docs/06-PRIVACY-SECURITY.md section 3.1 says: mode base,
/// DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, ChaCha20-Poly1305, `info` = `bellohub/inbox/v1`, AAD from the envelope's
/// own fields. The version and suite are checked before any key is touched. Pure given a private key, so the shared
/// vectors (`web/test/vectors/`) prove it against the page and the backend.
enum EnvelopeOpener {
    static let info = Data("bellohub/inbox/v1".utf8)
    static let suite = HPKE.Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .chaChaPoly)

    enum Failure: Error, Equatable {
        case unsupported
        case malformed
        case openFailed
    }

    /// The plaintext, or a `Failure`. `_pad` stays in the bytes: the payload decoders ignore it.
    static func open(_ envelope: SealedEnvelope, with privateKey: Curve25519.KeyAgreement.PrivateKey) throws -> Data {
        guard envelope.isSupported else { throw Failure.unsupported }
        guard let enc = Data(base64URL: envelope.enc), enc.count == 32, let ct = Data(base64URL: envelope.ct),
              ct.count >= 16
        else { throw Failure.malformed }
        do {
            var recipient = try HPKE.Recipient(
                privateKey: privateKey, ciphersuite: suite, info: info, encapsulatedKey: enc
            )
            return try recipient.open(ct, authenticating: envelope.aad)
        } catch {
            throw Failure.openFailed
        }
    }

    #if DEBUG
    /// Seals like the page does, for previews, UI-test fixtures and tests. Never used by the app itself.
    static func seal(
        _ plaintext: Data, to publicKey: Curve25519.KeyAgreement.PublicKey, kind: MailboxKind, itemId: String
    ) throws -> SealedEnvelope {
        let keyId = KeyDerivation.keyID(forPublicKey: publicKey.rawRepresentation)
        var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: suite, info: info)
        let aad = Data("bellohub/v1|\(kind.rawValue)|\(itemId)|\(keyId)".utf8)
        let ct = try sender.seal(plaintext, authenticating: aad)
        return SealedEnvelope(
            keyId: keyId, kind: kind.rawValue, itemId: itemId,
            enc: sender.encapsulatedKey.base64URLEncodedString(), ct: ct.base64URLEncodedString()
        )
    }
    #endif
}

extension Data {
    /// RFC 4648 section 5 without padding, as the envelopes and keys are written; padded input is accepted too.
    init?(base64URL text: String) {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }
}
