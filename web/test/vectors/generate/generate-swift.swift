// Writes web/test/vectors/swift-sealed.json: the plaintexts of js-sealed.json sealed by Apple's CryptoKit (the
// library the iPhone opens envelopes with), so the page's test suite and Python can prove they open what CryptoKit
// seals. The other direction (CryptoKit opens what the page sealed) is BelloHubTests/Managers/Vault/InboxVectorsTests.
//
//   xcrun swift web/test/vectors/generate/generate-swift.swift web/test/vectors/js-sealed.json web/test/vectors/swift-sealed.json
//
// CryptoKit has no way to fix the ephemeral key, so every run gives new envelopes: the file is a committed fixture,
// regenerated only when the plaintexts change. The suite and framing are written again here from docs/06 section 3
// (they are not imported from the app), exactly like the app's `EnvelopeOpener` and the page's `seal.ts`.

import CryptoKit
import Foundation

struct Recipient: Codable {
    let privateKey: String
    let publicKey: String
    let keyId: String
}

struct SourceCase: Decodable {
    let name: String
    let recipient: String
    let kind: String
    let hasPhoto: Bool
    let itemId: String
    let plaintext: String
}

struct SourceFile: Decodable {
    let recipients: [String: Recipient]
    let cases: [SourceCase]
}

struct Envelope: Codable {
    let v: Int
    let suite: String
    let keyId: String
    let kind: String
    let itemId: String
    let enc: String
    let ct: String
}

struct OutputCase: Codable {
    let name: String
    let recipient: String
    let kind: String
    let hasPhoto: Bool
    let itemId: String
    let plaintext: String
    let envelope: Envelope
}

struct OutputFile: Codable {
    let schema: Int
    let description: String
    let generator: String
    let recipients: [String: Recipient]
    let cases: [OutputCase]
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func bytes(_ text: String) -> Data {
    var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    guard let data = Data(base64Encoded: base64) else { fatalError("not base64url: \(text.prefix(16))") }
    return data
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: generate-swift.swift <js-sealed.json> <swift-sealed.json>\n".utf8))
    exit(2)
}
guard #available(macOS 14, *) else { fatalError("CryptoKit HPKE needs macOS 14") }

let source = try JSONDecoder().decode(
    SourceFile.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
)
let suite = HPKE.Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .chaChaPoly)
let info = Data("bellohub/inbox/v1".utf8)
var cases: [OutputCase] = []
for item in source.cases {
    guard let recipient = source.recipients[item.recipient] else { fatalError("no recipient \(item.recipient)") }
    let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: bytes(recipient.publicKey))
    let keyId = base64URL(Data(SHA256.hash(data: publicKey.rawRepresentation)).prefix(8))
    precondition(keyId == recipient.keyId, "key id derivation")
    var sender = try HPKE.Sender(recipientKey: publicKey, ciphersuite: suite, info: info)
    let aad = Data("bellohub/v1|\(item.kind)|\(item.itemId)|\(keyId)".utf8)
    let ct = try sender.seal(Data(item.plaintext.utf8), authenticating: aad)
    let envelope = Envelope(
        v: 1, suite: "hpke-x25519-hkdf-sha256-chacha20poly1305", keyId: keyId, kind: item.kind, itemId: item.itemId,
        enc: base64URL(sender.encapsulatedKey), ct: base64URL(ct)
    )
    cases.append(OutputCase(
        name: item.name, recipient: item.recipient, kind: item.kind, hasPhoto: item.hasPhoto, itemId: item.itemId,
        plaintext: item.plaintext, envelope: envelope
    ))
}
let output = OutputFile(
    schema: 1,
    description: "The plaintexts of js-sealed.json sealed by Apple CryptoKit (HPKE.Sender), random ephemeral keys. "
        + "Opening each `envelope` with the private key of `recipient` must give exactly `plaintext`. Opened by the "
        + "page's suite (test/unit/crypto.cross-implementation.test.ts) and by Python (generate/verify_js.py).",
    generator: "web/test/vectors/generate/generate-swift.swift",
    recipients: source.recipients.filter { key, _ in cases.contains { $0.recipient == key } },
    cases: cases
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
var data = try encoder.encode(output)
data.append(Data("\n".utf8))
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("wrote \(CommandLine.arguments[2]) (\(cases.count) envelopes)")
