//
//  OnboardingViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The workspace setup, from "About you" to "Ready". One ViewModel for every step, so going back and forward keeps
/// each choice (docs/04-ARCHITECTURE.md section 5). Nothing is saved until the end: `finish()` stores the profile,
/// services, tags and record template together.
@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .about
    /// Which way the last move went, so the next screen slides in from the right side.
    private(set) var isMovingForward = true
    private(set) var draft: OnboardingDraft
    private(set) var catalog: ProfessionCatalog
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var result: OnboardingResult?

    private let profile: ProfileService
    let regions: RegionCatalog
    private let deviceTimeZoneID: String
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private let onFinished: @MainActor () -> Void

    init(
        draft: OnboardingDraft,
        catalog: ProfessionCatalog,
        profile: ProfileService,
        regions: RegionCatalog = RegionCatalog(presets: []),
        deviceTimeZoneID: String = TimeZone.current.identifier,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        onFinished: @escaping @MainActor () -> Void
    ) {
        self.draft = draft
        self.catalog = catalog
        self.profile = profile
        self.regions = regions
        self.deviceTimeZoneID = deviceTimeZoneID
        self.now = now
        self.makeID = makeID
        self.onFinished = onFinished
    }

    // MARK: - Navigation

    var canContinue: Bool { OnboardingRules.canContinue(from: step, draft: draft) }

    func goNext() {
        guard canContinue, let next = step.next else { return }
        isMovingForward = true
        step = next
    }

    func goBack() {
        guard let previous = step.previous else { return }
        isMovingForward = false
        step = previous
    }

    // MARK: - About you

    func setDisplayName(_ name: String) { draft.displayName = name }
    func setBusinessName(_ name: String) { draft.businessName = name }

    /// The region she works in, as a preset (nil only if the table has no such code).
    var region: RegionPreset? { regions.preset(for: draft.regionCode) }

    func setRegion(_ preset: RegionPreset) {
        draft.changeRegion(to: preset, deviceTimeZoneID: deviceTimeZoneID)
    }

    // MARK: - Profession

    var availableProfessions: [ProfessionEntry] { catalog.entries }

    func isSelected(_ profession: ProfessionID) -> Bool { draft.professions.contains(profession) }

    /// Switches a profession on or off. Her service and tag picks follow: a profession she drops takes its picks
    /// with it, and one she adds brings its preselected suggestions.
    func toggle(_ profession: ProfessionID) {
        let previous = draft.professions
        var updated = previous
        if let index = updated.firstIndex(of: profession) {
            updated.remove(at: index)
        } else {
            updated.append(profession)
        }
        draft.selectedServiceKeys = OnboardingSuggestions.reconciledServiceKeys(
            selected: draft.selectedServiceKeys, previous: previous, current: updated, in: catalog
        )
        draft.selectedTagKeys = OnboardingSuggestions.reconciledTagKeys(
            selected: draft.selectedTagKeys, previous: previous, current: updated, in: catalog
        )
        draft.professions = updated
        if let current = draft.recordProfession, !updated.contains(current) { draft.recordProfession = nil }
    }

    // MARK: - Services

    var suggestedServices: [SuggestedService] {
        OnboardingSuggestions.services(for: draft.professions, in: catalog)
    }

    func isServiceSelected(_ key: String) -> Bool { draft.selectedServiceKeys.contains(key) }

    func toggleService(_ key: String) {
        if draft.selectedServiceKeys.contains(key) {
            draft.selectedServiceKeys.remove(key)
        } else {
            draft.selectedServiceKeys.insert(key)
        }
    }

    /// Adds a service she typed. Returns false (and adds nothing) when the sheet's values are not valid.
    @discardableResult
    func addCustomService(_ service: DraftService) -> Bool {
        guard OnboardingRules.issues(in: service).isEmpty else { return false }
        draft.customServices.append(service)
        return true
    }

    func removeCustomService(id: UUID) {
        draft.customServices.removeAll { $0.id == id }
    }

    // MARK: - Terminology

    func setClientTerm(_ term: ClientTerm) { draft.clientTerm = term }

    /// Names that already exist on this step: the chosen services and what she added.
    var knownNames: [String] {
        suggestedServices.filter { draft.selectedServiceKeys.contains($0.key) }.map(\.name)
            + draft.customServices.map(\.name) + draft.vocabulary.map(\.text)
    }

    @discardableResult
    func addVocabulary(_ raw: String, kind: VocabularyKind) -> Bool {
        guard let name = OnboardingRules.acceptedName(raw, existing: knownNames) else { return false }
        draft.vocabulary.append(VocabularyTerm(id: makeID(), text: name, kind: kind))
        return true
    }

    func removeVocabulary(id: UUID) {
        draft.vocabulary.removeAll { $0.id == id }
    }

    // MARK: - Tags

    var suggestedTags: [SuggestedTag] {
        OnboardingSuggestions.tags(for: draft.professions, in: catalog)
    }

    func isTagSelected(_ key: String) -> Bool { draft.selectedTagKeys.contains(key) }

    func toggleTag(_ key: String) {
        if draft.selectedTagKeys.contains(key) {
            draft.selectedTagKeys.remove(key)
        } else {
            draft.selectedTagKeys.insert(key)
        }
    }

    @discardableResult
    func addCustomTag(_ raw: String) -> Bool {
        let existing = suggestedTags.map(\.name) + draft.customTags
        guard let name = OnboardingRules.acceptedName(raw, existing: existing) else { return false }
        draft.customTags.append(name)
        return true
    }

    func removeCustomTag(_ name: String) {
        draft.customTags.removeAll { $0 == name }
    }

    // MARK: - Record

    /// The profession whose fields the Record step shows: her pick, or the first one she chose.
    var recordProfession: ProfessionID? {
        draft.recordProfession.flatMap { draft.professions.contains($0) ? $0 : nil } ?? draft.professions.first
    }

    func showRecord(of profession: ProfessionID) { draft.recordProfession = profession }

    func fields(of profession: ProfessionID) -> [SuggestedField] {
        catalog.entry(for: profession)?.fields ?? []
    }

    func isFieldOn(_ field: SuggestedField, of profession: ProfessionID) -> Bool {
        draft.fieldOverrides[RecordFieldSetting(profession: profession, key: field.key, isOn: false).id] ?? field.on
    }

    func setField(_ field: SuggestedField, of profession: ProfessionID, on: Bool) {
        let id = RecordFieldSetting(profession: profession, key: field.key, isOn: on).id
        draft.fieldOverrides[id] = on == field.on ? nil : on
    }

    func isIntakeOn(_ item: IntakeItem, of profession: ProfessionID) -> Bool {
        let id = IntakeSetting(profession: profession, item: item, isOn: false).id
        return draft.intakeOverrides[id] ?? (catalog.entry(for: profession)?.intake.contains(item) ?? false)
    }

    func setIntake(_ item: IntakeItem, of profession: ProfessionID, on: Bool) {
        let id = IntakeSetting(profession: profession, item: item, isOn: on).id
        let defaultOn = catalog.entry(for: profession)?.intake.contains(item) ?? false
        draft.intakeOverrides[id] = on == defaultOn ? nil : on
    }

    // MARK: - Finish

    /// Fire-and-forget entry point for the button; `finishAsync()` is what tests await.
    func finish() {
        Task { await finishAsync() }
    }

    /// Saves everything the setup collected. After a failure she stays on the screen and can try again.
    func finishAsync() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let built = OnboardingBuilder.build(draft: draft, catalog: catalog, now: now(), makeID: makeID)
        do {
            try await profile.saveOnboarding(built)
            result = built
            onFinished()
        } catch {
            errorMessage = String(
                localized: "onb.ready.saveError",
                defaultValue: "We could not save your workspace. Check that your iPhone has space and try again."
            )
        }
    }

    /// Number of record fields switched on for a profession, for "7 of 8 on".
    func onCount(for profession: ProfessionID) -> Int {
        fields(of: profession).filter { isFieldOn($0, of: profession) }.count
    }
}
