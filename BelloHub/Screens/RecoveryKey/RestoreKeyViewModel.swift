//
//  RestoreKeyViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The restore flow on a new iPhone (docs/06-PRIVACY-SECURITY.md section 4.3): she types the 12 words, a mistyped
/// word is named by its position, and a good phrase installs the seed so the records decrypt.
@MainActor
@Observable
final class RestoreKeyViewModel {
    var text = ""
    private(set) var issue: Issue?
    private(set) var restored = false

    enum Issue: Equatable, Sendable {
        case wordCount(Int)
        case unknownWord(position: Int)
        case checksum
        case failed
    }

    private let service: RecoveryKeyService

    init(service: RecoveryKeyService) {
        self.service = service
    }

    var typedCount: Int { RecoveryWordsPresentation.typedWordCount(text) }
    var canRestore: Bool { typedCount == RecoveryPhrase.wordCount }

    func restore() {
        issue = nil
        do {
            try service.restore(words: text)
            restored = true
        } catch let failure as RecoveryPhrase.Failure {
            switch failure {
            case .wrongWordCount(let count): issue = .wordCount(count)
            case .unknownWord(let position): issue = .unknownWord(position: position)
            case .checksumMismatch: issue = .checksum
            case .wrongEntropyLength: issue = .failed
            }
        } catch {
            issue = .failed
        }
    }
}
