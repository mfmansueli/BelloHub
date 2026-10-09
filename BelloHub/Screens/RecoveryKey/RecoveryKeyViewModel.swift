//
//  RecoveryKeyViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Recovery key (7.9): reveal behind Face ID, the text file for Files and the printer, the
/// "I saved it" confirmation. The revealed phrase lives only in this ViewModel and is dropped with the screen.
@MainActor
@Observable
final class RecoveryKeyViewModel {
    private(set) var phrase: RecoveryPhrase?
    private(set) var isRevealing = false
    private(set) var revealNotice: RevealNotice?
    var confirmsSafe = false
    private(set) var done = false
    private(set) var exportFile: ProtectedTemporaryFile?

    enum RevealNotice: Equatable, Sendable {
        case notRecognized
        case noKey
    }

    private let service: RecoveryKeyService
    private let printer: any DocumentPrinting
    let businessName: String

    init(service: RecoveryKeyService, printer: any DocumentPrinting = SystemDocumentPrinter(), businessName: String) {
        self.service = service
        self.printer = printer
        self.businessName = businessName
    }

    // MARK: - Reading

    var status: RecoveryKeyStatus { service.status }
    var biometryKind: BiometryKind { service.biometryKind }
    var isRevealed: Bool { phrase != nil }
    var cells: [RecoveryWordsPresentation.Cell] { RecoveryWordsPresentation.cells(phrase) }
    var canConfirm: Bool { isRevealed && confirmsSafe }

    // MARK: - Reveal

    func reveal() {
        Task { await revealAsync() }
    }

    func revealAsync() async {
        guard !isRevealing, !isRevealed else { return }
        isRevealing = true
        revealNotice = nil
        defer { isRevealing = false }
        switch await service.reveal() {
        case .revealed(let revealed): phrase = revealed
        case .cancelled: break
        case .notRecognized: revealNotice = .notRecognized
        case .noKey: revealNotice = .noKey
        }
    }

    // MARK: - Save and print

    /// Writes the text file for the share sheet (Files). Returns its URL; the file is removed with `discardExport`.
    func prepareFile(locale: Locale) -> URL? {
        guard let phrase else { return nil }
        discardExport()
        let text = RecoveryWordsPresentation.fileText(phrase, businessName: businessName, locale: locale)
        exportFile = try? ProtectedTemporaryFile.write(Data(text.utf8), named: RecoveryWordsPresentation.fileName)
        return exportFile?.url
    }

    func discardExport() {
        exportFile?.remove()
        exportFile = nil
    }

    func printKey(locale: Locale) {
        guard let phrase else { return }
        printer.printDocument(
            text: RecoveryWordsPresentation.fileText(phrase, businessName: businessName, locale: locale),
            jobName: RecoveryWordsPresentation.fileName
        )
    }

    // MARK: - Confirm

    func confirmSaved() {
        guard canConfirm else { return }
        service.markSaved()
        done = true
    }

    /// The screen leaves: the words leave memory and the temp file goes.
    func clear() {
        phrase = nil
        discardExport()
    }
}
