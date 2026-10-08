//
//  RecoveryPhrase.swift
//  BelloHub
//

import CryptoKit
import Foundation

/// The 12 recovery words (D22): BIP-39 encoding of 128 bits of entropy with its 4-bit checksum, so a mistyped word
/// is caught. This is only the mnemonic encode and decode; it is not a wallet and nothing is derived with
/// PBKDF2. The words are shown once, behind Face ID, and never leave the phone through Bello Hub.
struct RecoveryPhrase: Equatable, Sendable {
    enum Failure: Error, Equatable {
        case wrongWordCount(Int)
        /// The word at this 1-based position is not in the list.
        case unknownWord(position: Int)
        /// All words exist but the checksum does not match: a word was mistyped or swapped.
        case checksumMismatch
        case wrongEntropyLength
    }

    static let wordCount = 12
    let words: [String]
    let entropy: Data

    /// Encodes 16 bytes of entropy as 12 words.
    init(entropy: Data) throws {
        guard entropy.count == KeyDerivation.entropyLength else { throw Failure.wrongEntropyLength }
        let checksumBits = Self.checksumBits(of: entropy)
        let bits = Self.bits(of: entropy) + checksumBits
        self.words = stride(from: 0, to: bits.count, by: 11).map { start in
            let index = bits[start..<start + 11].reduce(0) { ($0 << 1) | Int($1) }
            return Bip39Wordlist.words[index]
        }
        self.entropy = entropy
    }

    /// Reads what a person typed: any case, any spacing, newlines allowed.
    init(parsing text: String) throws {
        let typed = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard typed.count == Self.wordCount else { throw Failure.wrongWordCount(typed.count) }
        var bits: [UInt8] = []
        for (offset, word) in typed.enumerated() {
            guard let index = Self.index(of: word) else { throw Failure.unknownWord(position: offset + 1) }
            bits += (0..<11).map { UInt8((index >> (10 - $0)) & 1) }
        }
        let entropy = Self.bytes(fromBits: Array(bits.prefix(128)))
        guard Array(bits.suffix(4)) == Self.checksumBits(of: entropy) else { throw Failure.checksumMismatch }
        self.words = typed
        self.entropy = entropy
    }

    var displayText: String {
        words.joined(separator: " ")
    }

    // MARK: - Bits

    private static let indexByWord: [String: Int] = Dictionary(
        uniqueKeysWithValues: Bip39Wordlist.words.enumerated().map { ($1, $0) }
    )

    private static func index(of word: String) -> Int? {
        indexByWord[word]
    }

    private static func bits(of data: Data) -> [UInt8] {
        data.flatMap { byte in (0..<8).map { UInt8((byte >> (7 - $0)) & 1) } }
    }

    /// The first `ENT / 32` bits of SHA-256(entropy): 4 bits for 128 bits of entropy.
    private static func checksumBits(of entropy: Data) -> [UInt8] {
        let first = Array(SHA256.hash(data: entropy)).first ?? 0
        return (0..<(entropy.count * 8 / 32)).map { UInt8((first >> (7 - $0)) & 1) }
    }

    private static func bytes(fromBits bits: [UInt8]) -> Data {
        Data(stride(from: 0, to: bits.count, by: 8).map { start in
            bits[start..<start + 8].reduce(UInt8(0)) { ($0 << 1) | $1 }
        })
    }
}
