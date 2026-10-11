//
//  OnboardingViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The workspace setup, from "About you" to "Ready". One ViewModel for every step, so going back and forward keeps
/// each choice (docs/04-ARCHITECTURE.md section 5). Nothing reaches the vault until the end: `finish()` stores the
/// profile, services, tags and record template together. Every change is saved as progress (`OnboardingProgressStore`),
/// so a relaunch resumes on the same step with the same choices.
@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var step: OnboardingStep = .about {
        didSet { saveProgress() }
    }
    /// Which way the last move went, so the next screen slides in from the right side.
    private(set) var isMovingForward = true
    private(set) var draft: OnboardingDraft {
        didSet { saveProgress() }
    }
    private(set) var catalog: ProfessionCatalog
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var result: OnboardingResult?

    private let profile: ProfileService
    let regions: RegionCatalog
    private let progress: OnboardingProgressStore?
    private let deviceTimeZoneID: String
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private let onFinished: @MainActor () -> Void

    init(
        draft: OnboardingDraft,
        catalog: ProfessionCatalog,
        profile: ProfileService,
        regions: RegionCatalog = RegionCatalog(presets: []),
        progress: OnboardingProgressStore? = nil,
        deviceTimeZoneID: String = TimeZone.current.identifier,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        onFinished: @escaping @MainActor () -> Void
    ) {
        let saved = progress?.load()
        self.draft = saved?.draft ?? draft
        self.step = saved?.step ?? .about
        self.catalog = catalog
        self.profile = profile
        self.regions = regions
        self.progress = progress
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

    /// Switches a profession on or off. Her service and tag picks follow: a profession she drops takes its picks with
    /// it; the first service follows her first profession unless she chose one that is still offered; tags take the
    /// catalog's preselection of a profession she adds (she edits them later in More, Tags).
    func toggle(_ profession: ProfessionID) {
        let previous = draft.professions
        var updated = previous
        if let index = updated.firstIndex(of: profession) {
            updated.remove(at: index)
        } else {
            updated.append(profession)
        }
        let services = OnboardingSuggestions.reconciledServices(
            selected: draft.selectedServiceKeys, firstKey: draft.firstServiceKey, current: updated, in: catalog
        )
        var changed = draft
        changed.selectedServiceKeys = services.selected
        changed.firstServiceKey = services.firstKey
        changed.selectedTagKeys = OnboardingSuggestions.reconciledTagKeys(
            selected: draft.selectedTagKeys, previous: previous, current: updated, in: catalog
        )
        changed.professions = updated
        if let current = changed.recordProfession, !updated.contains(current) { changed.recordProfession = nil }
        draft = changed
    }

    // MARK: - First service

    var suggestedServices: [SuggestedService] {
        OnboardingSuggestions.services(for: draft.professions, in: catalog)
    }

    /// The suggestion she starts with.
    var firstService: SuggestedService? {
        suggestedServices.first { $0.key == draft.firstServiceKey }
    }

    /// The other suggestions, offered as optional extras.
    var otherServices: [SuggestedService] {
        suggestedServices.filter { $0.key != draft.firstServiceKey }
    }

    func chooseFirstService(_ key: String) {
        guard key != draft.firstServiceKey, suggestedServices.contains(where: { $0.key == key }) else { return }
        var changed = draft
        if let old = changed.firstServiceKey { changed.selectedServiceKeys.remove(old) }
        changed.selectedServiceKeys.insert(key)
        changed.firstServiceKey = key
        draft = changed
    }

    /// The duration of a suggested service: hers, or the catalog's.
    func minutes(of service: SuggestedService) -> Int {
        draft.serviceMinutes[service.key] ?? service.minutes
    }

    func setMinutes(_ minutes: Int, of service: SuggestedService) {
        draft.serviceMinutes[service.key] = minutes == service.minutes ? nil : minutes
    }

    func price(of service: SuggestedService) -> Decimal? {
        draft.servicePrices[service.key]
    }

    /// A price she typed (nil clears it: prices are optional).
    func setPrice(_ amount: Decimal?, of service: SuggestedService) {
        draft.servicePrices[service.key] = amount
    }

    func isServiceSelected(_ key: String) -> Bool { draft.selectedServiceKeys.contains(key) }

    /// Switches an extra suggestion on or off. The first service stays: it is changed, never removed.
    func toggleService(_ key: String) {
        guard key != draft.firstServiceKey else { return }
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
            progress?.clear()
            onFinished()
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "onb.ready.saveError",
                defaultValue: "We could not save your workspace. Check that your iPhone has space and try again."
            ))
        }
    }

    // MARK: - Private

    private func saveProgress() {
        guard result == nil else { return }
        progress?.save(OnboardingProgress(stepName: step.name, draft: draft))
    }
}
