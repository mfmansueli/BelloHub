//
//  ProtectedTemporaryFile.swift
//  BelloHub
//

import Foundation

/// A file the share sheet hands out, written with complete file protection into the app's own temporary folder and
/// deleted when the caller is done (docs/06-PRIVACY-SECURITY.md section 4.4). Never the system-wide `/tmp`.
struct ProtectedTemporaryFile: Sendable {
    let url: URL

    /// Writes `data` under a fresh folder so two exports never collide, and the whole folder is removed at once.
    static func write(_ data: Data, named name: String) throws -> ProtectedTemporaryFile {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return ProtectedTemporaryFile(url: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
