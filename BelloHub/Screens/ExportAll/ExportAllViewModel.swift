//
//  ExportAllViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Export all my data (7.8): what to include, prepare, share, and the clean-up of the temp
/// file when the screen leaves.
@MainActor
@Observable
final class ExportAllViewModel {
    var contents = ExportContents()

    private let export: DataExportService
    private let profile: ProfileService

    init(export: DataExportService, profile: ProfileService) {
        self.export = export
        self.profile = profile
    }

    var isPreparing: Bool { export.isPreparing }
    var errorMessage: String? { export.errorMessage }
    var fileURL: URL? { export.file?.url }

    func prepare(locale: Locale) {
        Task { await prepareAsync(locale: locale) }
    }

    func prepareAsync(locale: Locale) async {
        await export.prepare(contents: contents, locale: locale, profile: profile.profile)
    }

    /// The screen left or she started over: the temp file goes.
    func discard() {
        export.discard()
    }
}
