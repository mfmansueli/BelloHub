//
//  InboxKeyVerifier.swift
//  BelloHub
//

/// Public-key integrity (docs/06-PRIVACY-SECURITY.md section 3.2, threat "a malicious server swaps the key"): after a
/// publish, the key her booking page actually serves (`getPublicPage`) must be the one this iPhone derived from her
/// recovery words. A mismatch is published over once (an honest server takes the right key back); if the page still
/// serves another key, the publish ends in `InboxKeyMismatchError` and her page is not published again until she
/// retries, because a client's health form would be sealed to a key that is not hers.
struct InboxKeyVerifier {
    let repository: any BookingRepository

    /// Throws `InboxKeyMismatchError` when the served key is still wrong after one republish. A page that serves no
    /// key yet (not found right after a claim) is not a mismatch.
    func verify(expected: InboxPublicKey, slug: String, republish: () async throws -> Void) async throws {
        guard let served = try await repository.servedInboxKey(slug: slug), !Self.matches(served, expected) else {
            return
        }
        try await republish()
        guard let again = try await repository.servedInboxKey(slug: slug), !Self.matches(again, expected) else {
            return
        }
        throw InboxKeyMismatchError()
    }

    static func matches(_ served: InboxPublicKey, _ expected: InboxPublicKey) -> Bool {
        served.pub == expected.pub && served.keyId == expected.keyId
    }
}
