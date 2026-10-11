//
//  WorkplaceViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of "Where you work" (Booking settings): the address she types, who may see it, and a live preview
/// of what a client gets. Nothing is saved until she taps Save, so the page is not republished on every letter; it is
/// saved through the shared `BookingSetupEditor` and published with her page (`PublishPayloads.location`).
@MainActor
@Observable
final class WorkplaceViewModel {
    var street: String
    var postalCode: String
    var city: String
    var countryCode: String
    var directions: String
    var visibility: LocationVisibility
    private(set) var isSaving = false

    let editor: BookingSetupEditor
    let businessRegion: String

    init(editor: BookingSetupEditor, businessRegion: String) {
        self.editor = editor
        self.businessRegion = businessRegion
        let stored = editor.setup.location
        street = stored?.street ?? ""
        postalCode = stored?.postalCode ?? ""
        city = stored?.city ?? ""
        countryCode = stored?.countryCode ?? businessRegion
        directions = stored?.directions ?? ""
        visibility = stored?.visibility ?? .confirmedClients
    }

    // MARK: - Reading

    /// What she typed, cleaned the way it will be stored.
    var draft: BusinessLocation {
        BusinessLocation(
            street: BusinessLocationFormat.clean(street), postalCode: BusinessLocationFormat.clean(postalCode),
            city: BusinessLocationFormat.clean(city), countryCode: countryCode,
            directions: BusinessLocationFormat.clean(directions), visibility: visibility
        )
    }

    var stored: BusinessLocation? { editor.setup.location }

    var isComplete: Bool { BusinessLocationFormat.isComplete(draft) }

    var isTooLong: Bool { BusinessLocationFormat.tooLong(draft) }

    var hasChanges: Bool { stored != draft }

    var canSave: Bool { isComplete && !isTooLong && hasChanges && !isSaving }

    /// The saved address is what the fields show.
    var isSaved: Bool { stored != nil && !hasChanges }

    /// What a client sees, from the fields as they are now; nil until street and city are filled.
    var previewLines: [String]? {
        isComplete ? BusinessLocationFormat.lines(draft) : nil
    }

    var previewDirections: String? {
        let text = draft.directions
        return isComplete && !text.isEmpty ? text : nil
    }

    var appleMapsURL: URL? { isComplete ? BusinessLocationFormat.appleMapsURL(draft) : nil }

    var googleMapsURL: URL? { isComplete ? BusinessLocationFormat.googleMapsURL(draft) : nil }

    var errorMessage: String? { editor.saveErrorMessage }

    // MARK: - Actions

    func appear() {
        editor.adoptStored()
    }

    func save() {
        Task { await saveAsync() }
    }

    @discardableResult
    func saveAsync() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        let location = draft
        return await editor.apply { $0.location = location }
    }

    func remove() {
        Task { await removeAsync() }
    }

    /// Forgets the address everywhere: the next publish carries none, so the server removes it too.
    @discardableResult
    func removeAsync() async -> Bool {
        let removed = await editor.apply { $0.location = nil }
        if removed {
            street = ""
            postalCode = ""
            city = ""
            countryCode = businessRegion
            directions = ""
            visibility = .confirmedClients
        }
        return removed
    }

    func dismissError() {
        editor.dismissSaveError()
    }
}
