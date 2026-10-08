//
//  RecoveryPhraseTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecoveryPhrase and the BIP-39 list")
struct RecoveryPhraseTests {
    @Test("The word list has 2048 unique words, from abandon to zoo")
    func wordlistShape() {
        let words = Bip39Wordlist.words

        #expect(words.count == 2048)
        #expect(Set(words).count == 2048)
        #expect(words.first == "abandon")
        #expect(words.last == "zoo")
        #expect(words[1028] == "letter", "the first word of the BIP-39 vector for 0x8080...")
        #expect(Set(words.map { $0.prefix(4) }).count == 2048, "words are unique by their first four letters")
    }

    @Test("Entropy encodes to the words published with BIP-39", arguments: VaultVectors.bip39.indices)
    func publishedVectors(index: Int) throws {
        let vector = VaultVectors.bip39[index]
        let phrase = try RecoveryPhrase(entropy: Data(hexString: vector.entropy))

        #expect(phrase.displayText == vector.words)
    }

    @Test("The words decode back to the same entropy", arguments: VaultVectors.bip39.indices)
    func publishedVectorsDecode(index: Int) throws {
        let vector = VaultVectors.bip39[index]
        let phrase = try RecoveryPhrase(parsing: vector.words)

        #expect(phrase.entropy.hexString == vector.entropy)
    }

    @Test("The project's own vector (checked against a second implementation)")
    func projectVector() throws {
        #expect(try RecoveryPhrase(entropy: VaultVectors.entropy).displayText == VaultVectors.mnemonic)
        #expect(try RecoveryPhrase(parsing: VaultVectors.mnemonic).entropy == VaultVectors.entropy)
    }

    @Test("Random entropy round-trips through twelve words")
    func randomRoundTrip() throws {
        for _ in 0..<200 {
            let entropy = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
            let phrase = try RecoveryPhrase(entropy: entropy)

            #expect(phrase.words.count == 12)
            #expect(try RecoveryPhrase(parsing: phrase.displayText).entropy == entropy)
        }
    }

    @Test("Typing is forgiving: any case, any spacing, new lines")
    func forgivingInput() throws {
        let messy = "  Abandon  ABANDON abandon\nabandon abandon abandon\t"
            + "abandon abandon abandon abandon abandon ABOUT\n"

        #expect(try RecoveryPhrase(parsing: messy).entropy == Data(repeating: 0, count: 16))
    }

    @Test("The wrong number of words is reported with the count")
    func wrongCount() {
        #expect(throws: RecoveryPhrase.Failure.wrongWordCount(11)) {
            try RecoveryPhrase(parsing: Array(repeating: "abandon", count: 11).joined(separator: " "))
        }
        #expect(throws: RecoveryPhrase.Failure.wrongWordCount(0)) { try RecoveryPhrase(parsing: "   ") }
        #expect(throws: RecoveryPhrase.Failure.wrongWordCount(13)) {
            try RecoveryPhrase(parsing: VaultVectors.mnemonic + " zoo")
        }
    }

    @Test("A word that is not in the list is reported by position")
    func unknownWord() {
        let typed = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon aboot"

        #expect(throws: RecoveryPhrase.Failure.unknownWord(position: 12)) { try RecoveryPhrase(parsing: typed) }
    }

    @Test("One wrong word fails the checksum, so a typo is never accepted silently")
    func oneWrongWordFailsChecksum() {
        // 'about' replaced by 'above': both are real words, only the checksum can tell.
        let typed = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon above"

        #expect(throws: RecoveryPhrase.Failure.checksumMismatch) { try RecoveryPhrase(parsing: typed) }
    }

    @Test("Swapping two words fails the checksum")
    func swappedWords() {
        var words = VaultVectors.mnemonic.split(separator: " ").map(String.init)
        words.swapAt(1, 2)

        let swapped = words.joined(separator: " ")

        #expect(throws: RecoveryPhrase.Failure.checksumMismatch) { try RecoveryPhrase(parsing: swapped) }
    }

    @Test("Only 16 bytes of entropy are accepted")
    func wrongEntropyLength() {
        #expect(throws: RecoveryPhrase.Failure.wrongEntropyLength) { try RecoveryPhrase(entropy: Data(count: 15)) }
        #expect(throws: RecoveryPhrase.Failure.wrongEntropyLength) { try RecoveryPhrase(entropy: Data(count: 32)) }
    }
}
