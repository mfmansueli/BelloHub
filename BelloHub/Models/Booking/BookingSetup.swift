//
//  BookingSetup.swift
//  BelloHub
//

import Foundation

/// The booking page switches and its two policies, in one value (S5). One per vault, stored in the clear: nothing in
/// it is clinical. The server keeps the published copy; this one is what she edits.
///
/// The slug is her **chosen** address, not a claim: the server decides who owns an address when she goes online (S8),
/// so a saved slug can still turn out to be taken then.
struct BookingSetup: Identifiable, Hashable, Codable, Sendable {
    /// There is exactly one per vault, so a second device syncing cannot create a second one.
    static let singletonID = UUID(uuidString: "B3110000-0000-4000-8000-000000000003") ?? UUID()

    let id: UUID
    var page: BookingPageSettings
    var cancellation: CancellationPolicy
    var noShow: NoShowPolicy
    /// The address she picked (`bellohub.app/<slug>`), lowercase, already valid by `BookingSlug`. Nil until she picks.
    var slug: String?
    var updatedAt: Date

    init(
        page: BookingPageSettings = .standard,
        cancellation: CancellationPolicy = .standard,
        noShow: NoShowPolicy = .standard,
        slug: String? = nil,
        updatedAt: Date
    ) {
        self.id = Self.singletonID
        self.page = page
        self.cancellation = cancellation
        self.noShow = noShow
        self.slug = slug
        self.updatedAt = updatedAt
    }

    /// What a new professional starts with: the prototype's defaults, nothing chosen yet.
    static func starter(now: Date) -> BookingSetup {
        BookingSetup(updatedAt: now)
    }
}
