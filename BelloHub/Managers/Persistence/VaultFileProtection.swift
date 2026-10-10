//
//  VaultFileProtection.swift
//  BelloHub
//

import Foundation

/// The Data Protection class of the vault store (docs/06-PRIVACY-SECURITY.md section 4.4), set explicitly instead of
/// trusting the system default. `completeUntilFirstUserAuthentication`, not `complete`: the store must stay readable
/// for background sync (CloudKit mirroring, a silent push that opens the mailbox) while the phone is locked after its
/// first unlock. The fields inside are encrypted by the vault key anyway (D26); this is the layer under it.
enum VaultFileProtection {
    static let level = FileProtectionType.completeUntilFirstUserAuthentication

    /// The store file and its SQLite companions (`-wal`, `-shm`), which hold the same data.
    static func files(of storeURL: URL) -> [URL] {
        [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"), URL(fileURLWithPath: storeURL.path + "-shm")]
    }

    /// Sets `level` on the store's folder (new files inherit it) and on every store file that exists. A failure is
    /// returned, not thrown: a store that opened is better than none, and the caller records it.
    @discardableResult
    static func apply(to storeURL: URL, fileManager: FileManager = .default) -> [URL] {
        let attributes: [FileAttributeKey: Any] = [.protectionKey: level]
        let targets = [storeURL.deletingLastPathComponent()] + files(of: storeURL)
        return targets.filter { url in
            guard fileManager.fileExists(atPath: url.path) else { return false }
            do {
                try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
                return false
            } catch {
                return true
            }
        }
    }

    /// Whether the file reports `level` (the URL resource API names the same class `URLFileProtection`).
    static func isProtected(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.fileProtectionKey]))?.fileProtection
            == URLFileProtection.completeUntilFirstUserAuthentication
    }
}
