//
//  RecordTemplateViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Record fields screen (6.13): the fields of one profession switched on and off, the fields
/// she adds herself, and the intake items. Every change is saved as soon as she makes it, through `ProfileService`,
/// so there is no "Save changes" to forget and nothing is lost when she goes back.
///
/// The screen edits a working copy so a switch moves at once; the copy is written in order, and if a write fails it
/// is replaced by what the vault holds and the error is shown. Rules are in `RecordTemplateEditor`.
@MainActor
@Observable
final class RecordTemplateViewModel {
    /// What the screen shows: the stored template topped up with anything the catalog adds
    /// (`RecordTemplateEditor.completed`).
    private(set) var template: RecordTemplate
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var catalog: ProfessionCatalog

    private var chosenProfession: ProfessionID?
    private var lastWrite: Task<Bool, Never>?
    /// The last template the vault is known to hold, so a write that has nothing new to say is skipped.
    private var stored: RecordTemplate

    private let profile: ProfileService
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(
        profile: ProfileService,
        catalog: ProfessionCatalog,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.profile = profile
        self.catalog = catalog
        self.now = now
        self.makeID = makeID
        let initial = Self.completed(profile: profile, catalog: catalog, now: now())
        self.template = initial
        self.stored = initial
    }

    // MARK: - Reading

    /// The professions she has, in the order she chose them.
    var professions: [ProfessionID] { profile.profile?.professions ?? [] }

    /// The profession whose fields are on screen: her pick, or the first one she has.
    var selectedProfession: ProfessionID? {
        chosenProfession.flatMap { professions.contains($0) ? $0 : nil } ?? professions.first
    }

    /// What she calls the people she serves, for the line under the title.
    var clientTerm: ClientTerm { profile.clientTerm }

    func professionName(_ profession: ProfessionID) -> String {
        catalog.entry(for: profession)?.name ?? ""
    }

    func standardFields(for profession: ProfessionID) -> [RecordFieldSetting] {
        RecordTemplateEditor.standardFields(in: template, for: profession)
    }

    func customFields(for profession: ProfessionID) -> [RecordFieldSetting] {
        RecordTemplateEditor.customFields(in: template, for: profession)
    }

    /// The catalog of another interface language: the standard fields take its names at once (her own fields keep
    /// hers).
    func useCatalog(_ other: ProfessionCatalog) {
        catalog = other
    }

    /// The name to show for a field: her own for a custom field, the catalog's in the interface language otherwise. A
    /// field the catalog no longer lists shows its key rather than disappearing.
    func name(of field: RecordFieldSetting) -> String {
        if let custom = field.customName { return custom }
        return catalog.entry(for: field.profession)?.fields.first { $0.key == field.key }?.name ?? field.key
    }

    func isIntakeOn(_ item: IntakeItem, for profession: ProfessionID) -> Bool {
        template.isIntakeOn(item, for: profession)
    }

    /// Fields switched on and in total for a profession, for "7 of 8 on".
    func counts(for profession: ProfessionID) -> (on: Int, total: Int) {
        template.fieldCounts(for: [profession])
    }

    /// Whether she can still add a field of her own to the profession.
    func canAddField(for profession: ProfessionID) -> Bool {
        customFields(for: profession).count < RecordTemplateEditor.maximumCustomFields
    }

    /// The first thing wrong with a draft for the selected profession (nil when it can be saved), for the sheet to show
    /// while she types.
    func issue(in draft: RecordFieldDraft, editing key: String? = nil) -> RecordFieldIssue? {
        guard let scope = selectedScope else { return .notFound }
        return RecordTemplateEditor.issue(in: draft, template: template, scope: scope, editing: key)
    }

    // MARK: - Loading

    /// Entry point for appearing; `loadAsync()` is what `.refreshable` and tests await.
    func load() {
        Task { await loadAsync() }
    }

    /// Reads the template again, in case another screen or device changed it. Skipped while a write is in flight, so a
    /// stale read never undoes a switch she just made.
    func loadAsync() async {
        guard !isLoading, lastWrite == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await profile.reloadTemplate()
            let fresh = Self.completed(profile: profile, catalog: catalog, now: now())
            template = fresh
            stored = fresh
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "recordTemplate.error.load",
                defaultValue: "We could not read your record fields. Check that your iPhone is unlocked and try again."
            ))
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Editing

    func select(_ profession: ProfessionID) {
        chosenProfession = profession
    }

    /// A catalog field or one of hers switched on or off. Switching off only stops it being asked: what saved
    /// treatment records hold for it stays.
    func setField(_ key: String, on: Bool) {
        guard let profession = selectedProfession else { return }
        change { RecordTemplateEditor.setting(key, on: on, for: profession, in: $0, now: now()) }
    }

    func setIntake(_ item: IntakeItem, on: Bool) {
        guard let profession = selectedProfession else { return }
        change { RecordTemplateEditor.settingIntake(item, on: on, for: profession, in: $0, now: now()) }
    }

    /// Adds a field of hers to the selected profession. Returns whether it was saved: false when the draft is not
    /// valid (the sheet shows why) or the vault refused the write (the screen shows the error).
    func addField(_ draft: RecordFieldDraft) async -> Bool {
        guard let scope = selectedScope else { return false }
        let result = RecordTemplateEditor.adding(draft, to: template, scope: scope, makeID: makeID, now: now())
        guard case .success(let updated) = result else { return false }
        errorMessage = nil
        template = updated
        return await persist()
    }

    /// Renames one of her fields or changes its options or unit. Same result as `addField`.
    func updateField(_ key: String, with draft: RecordFieldDraft) async -> Bool {
        guard let scope = selectedScope else { return false }
        let result = RecordTemplateEditor.updating(key, with: draft, in: template, scope: scope, now: now())
        guard case .success(let updated) = result else { return false }
        errorMessage = nil
        template = updated
        return await persist()
    }

    /// Deletes one of her fields. What saved treatment records hold for it is not touched.
    func deleteField(_ key: String) async -> Bool {
        guard let profession = selectedProfession else { return false }
        errorMessage = nil
        template = RecordTemplateEditor.removing(key, for: profession, from: template, now: now())
        return await persist()
    }

    /// Entry point for the drag handles over her own fields.
    func moveFields(from source: IndexSet, to destination: Int) {
        guard let profession = selectedProfession else { return }
        change {
            RecordTemplateEditor.movingCustomFields(
                from: source, to: destination, for: profession, in: $0, now: now()
            )
        }
    }

    // MARK: - Saving

    /// Applies a change to the working copy at once and writes it in the background. A new change clears the error of
    /// the last one that failed; if this one fails too, the error comes back.
    private func change(_ edit: (RecordTemplate) -> RecordTemplate) {
        let updated = edit(template)
        guard updated != template else { return }
        errorMessage = nil
        template = updated
        Task { await persist() }
    }

    /// Writes the working copy after every earlier write has finished, so the vault always ends with the newest state.
    /// A write that finds nothing new to say returns at once. On failure the working copy goes back to what the vault
    /// holds and the error is shown.
    private func persist() async -> Bool {
        let previous = lastWrite
        let write = Task { @MainActor [self] () -> Bool in
            _ = await previous?.value
            let snapshot = template
            guard snapshot != stored else { return true }
            do {
                try await profile.saveTemplate(snapshot)
                stored = snapshot
                return true
            } catch {
                let revert = Self.completed(profile: profile, catalog: catalog, now: now())
                template = revert
                stored = revert
                errorMessage = String(interface: LocalizedStringResource(
                    "recordTemplate.error.save",
                    defaultValue: "We could not save this change. Check that your iPhone has space and try again."
                ))
                return false
            }
        }
        lastWrite = write
        isSaving = true
        let saved = await write.value
        if lastWrite == write {
            lastWrite = nil
            isSaving = false
        }
        return saved
    }

    // MARK: - Helpers

    /// The selected profession with the names of its catalog fields, which a field of hers may not repeat.
    private var selectedScope: RecordTemplateEditor.Scope? {
        selectedProfession.map { profession in
            RecordTemplateEditor.Scope(
                profession: profession, reservedNames: standardFields(for: profession).map { name(of: $0) }
            )
        }
    }

    private static func completed(profile: ProfileService, catalog: ProfessionCatalog, now: Date) -> RecordTemplate {
        RecordTemplateEditor.completed(
            profile.template, professions: profile.profile?.professions ?? [], catalog: catalog, now: now
        )
    }
}
