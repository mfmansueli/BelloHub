//
//  EnvelopeOpenerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// What the page's own code sealed (`web/test/vectors/js-sealed.json`, made by `web/test/vectors/generate-js.ts` with
/// hpke-js and the page's form code) goes through the app's real path: `EnvelopeOpener` opens it and the payload
/// readers (`IntakePayload`, `MailboxMessage`) read every field the page wrote. The other direction (the page opens
/// what CryptoKit seals) is `web/test/vectors/swift-sealed.json` in the web suite.
@Suite("EnvelopeOpener")
struct EnvelopeOpenerTests {
    private final class BundleToken {}

    private struct Recipient: Decodable {
        let privateKey: String
    }

    private struct Case: Decodable {
        let name: String
        let recipient: String
        let kind: String
        let plaintext: String
        let envelope: SealedEnvelope
    }

    private struct File: Decodable {
        let recipients: [String: Recipient]
        let cases: [Case]
    }

    private static let submitted = Date(timeIntervalSince1970: 1_791_468_201) // 2026-10-08T14:03:21Z

    private static func file() throws -> File {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "js-sealed", withExtension: "json"))
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
    }

    private static func key(_ file: File, _ item: Case) throws -> Curve25519.KeyAgreement.PrivateKey {
        let recipient = try #require(file.recipients[item.recipient])
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: #require(Data(base64URL: recipient.privateKey)))
    }

    private static func opened(_ name: String) throws -> Data {
        let file = try file()
        let item = try #require(file.cases.first { $0.name == name })
        return try EnvelopeOpener.open(item.envelope, with: key(file, item))
    }

    @Test("Every envelope the page sealed opens with the app's opener to the exact plaintext")
    func opensEveryPageEnvelope() throws {
        let file = try Self.file()
        #expect(file.cases.count >= 11)
        for item in file.cases {
            let plaintext = try EnvelopeOpener.open(item.envelope, with: Self.key(file, item))
            #expect(String(bytes: plaintext, encoding: .utf8) == item.plaintext, Comment(rawValue: item.name))
        }
    }

    @Test("Every intake the page sealed reads as an intake payload, schema 1 or 2, with its sent time")
    func readsEveryIntake() throws {
        let file = try Self.file()
        let intakes = file.cases.filter { $0.kind == "intake" }
        #expect(intakes.count >= 7)
        for item in intakes {
            let payload = try IntakePayload.decode(EnvelopeOpener.open(item.envelope, with: Self.key(file, item)))
            #expect(payload.bookingId == "bk_7Hq2xkP9", Comment(rawValue: item.name))
            #expect(!payload.answers.isEmpty, Comment(rawValue: item.name))
            #expect(payload.submittedAt == Self.submitted, Comment(rawValue: item.name))
        }
    }

    @Test("A schema 2 intake built by the page's form reads answer by answer")
    func readsPageAdultIntake() throws {
        let payload = try IntakePayload.decode(Self.opened("page-intake-schema2-adult"))
        #expect(payload.schema == 2)
        #expect(payload.localeId == "pt-BR")
        #expect(payload.formVersion == 3)
        #expect(payload.isForMinor == false)
        #expect(payload.minorName == nil)
        #expect(payload.clientName == nil)
        #expect(payload.answers == [
            "allergies": .choices(["latex", "fragrance"]),
            "medication": .yes,
            "pregnancy": .no,
            "anythingElse": .text("Pele sensível; fiz um peeling há duas semanas."),
        ])
    }

    @Test("A minor's intake keeps the young person's name and drops the adult-only questions")
    func readsPageMinorIntake() throws {
        let payload = try IntakePayload.decode(Self.opened("page-intake-schema2-minor"))
        #expect(payload.schema == 2)
        #expect(payload.isForMinor)
        #expect(payload.minorName == "لينا الحارثي")
        #expect(payload.answers["pregnancy"] == nil)
        #expect(payload.answers["allergies"] == .choices([HealthOption.noneKey]))
        #expect(payload.answers["anythingElse"] == .text("لا شيء 🌿"))
    }

    @Test("A check-in with a photo reads its feeling, note, photo bytes and sent time")
    func readsCheckinWithPhoto() throws {
        let data = try Self.opened("checkin-with-photo")
        let message = try #require(MailboxMessage.decode(
            data, kind: .checkin, id: "item", bookingId: "bk_7Hq2xkP9", receivedAt: Self.submitted
        ))
        guard case .checkin(let feeling, let note, let photo) = message.content else {
            Issue.record("not a check-in")
            return
        }
        #expect(feeling == "irritated")
        #expect(note == "Bochechas vermelhas desde a manhã.")
        let jpeg = try #require(photo)
        #expect(jpeg.starts(with: [0xFF, 0xD8]), "a JPEG")
        #expect(message.submittedAt == Self.submitted)
    }

    @Test("A check-in without a photo and both data requests read with their sent time")
    func readsTheOtherMessages() throws {
        let plain = try #require(MailboxMessage.decode(
            Self.opened("checkin-no-photo"), kind: .checkin, id: "a", bookingId: "b", receivedAt: Self.submitted
        ))
        #expect(plain.content == .checkin(feeling: "good", note: nil, photo: nil))
        #expect(plain.submittedAt == Self.submitted)

        let delete = try #require(MailboxMessage.decode(
            Self.opened("datarequest-delete"), kind: .datarequest, id: "c", bookingId: "b", receivedAt: Self.submitted
        ))
        #expect(delete.content == .dataRequest(request: "delete", name: "Helena Duarte", phone: "+5511987654321", note: nil))
        #expect(delete.submittedAt == Self.submitted)

        let copy = try #require(MailboxMessage.decode(
            Self.opened("datarequest-copy-note"), kind: .datarequest, id: "d", bookingId: "b", receivedAt: Self.submitted
        ))
        #expect(copy.content == .dataRequest(
            request: "copy", name: "José Ñandú", phone: "+34612345678", note: "Prefiero un PDF, gracias."
        ))
    }

    @Test("An envelope moved to another item, kind or key does not open")
    func refusesMovedEnvelopes() throws {
        let file = try Self.file()
        let item = try #require(file.cases.first)
        let key = try Self.key(file, item)
        let envelope = item.envelope
        let moved = [
            SealedEnvelope(keyId: envelope.keyId, kind: envelope.kind, itemId: "another", enc: envelope.enc,
                           ct: envelope.ct),
            SealedEnvelope(keyId: envelope.keyId, kind: "checkin", itemId: envelope.itemId, enc: envelope.enc,
                           ct: envelope.ct),
            SealedEnvelope(keyId: "AAAAAAAAAAA", kind: envelope.kind, itemId: envelope.itemId, enc: envelope.enc,
                           ct: envelope.ct),
        ]
        for wrong in moved {
            #expect(throws: EnvelopeOpener.Failure.openFailed) { try EnvelopeOpener.open(wrong, with: key) }
        }
        let future = SealedEnvelope(version: 2, keyId: envelope.keyId, kind: envelope.kind, itemId: envelope.itemId,
                                    enc: envelope.enc, ct: envelope.ct)
        #expect(throws: EnvelopeOpener.Failure.unsupported) { try EnvelopeOpener.open(future, with: key) }
    }

    @Test("What the app's debug sealer writes, its opener opens, with the page's AAD")
    func sealsAndOpens() throws {
        let key = Curve25519.KeyAgreement.PrivateKey()
        let plaintext = Data(#"{"schema":1,"request":"copy","name":"Zoë","phone":"+1","_pad":""}"#.utf8)
        let envelope = try EnvelopeOpener.seal(plaintext, to: key.publicKey, kind: .datarequest, itemId: "item-1")
        #expect(envelope.aad == Data("bellohub/v1|datarequest|item-1|\(envelope.keyId)".utf8))
        #expect(try EnvelopeOpener.open(envelope, with: key) == plaintext)
        #expect(throws: EnvelopeOpener.Failure.openFailed) {
            try EnvelopeOpener.open(envelope, with: Curve25519.KeyAgreement.PrivateKey())
        }
    }
}
