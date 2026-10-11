//
//  BookingSettingsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the booking page settings (6.7): whether the page takes bookings (with the pause and its return
/// date), new-client approval, guests per booking and the booking rules (buffer, notice, window) with the doors to her
/// hours, cancellations and no-show protection. Every change is saved as she makes it. The page switches go through the
/// `BookingSetupEditor` it shares with the policy screens; the three rules that live in her availability go through
/// `BookingSetupService` directly.
@MainActor
@Observable
final class BookingSettingsViewModel {
    let editor: BookingSetupEditor
    /// Her availability as the screen shows it: the buffer, notice and window rows.
    private(set) var availability: AvailabilitySettings
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// Her settings could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change to her availability could not be saved.
    private(set) var availabilityErrorMessage: String?
    private(set) var copiedLink = false
    /// Her services, for the "What clients see" preview. Empty when none or when they could not be read: the preview
    /// then uses a plain 60-minute visit.
    private(set) var services: [Service] = []
    /// The service the preview shows; nil is her longest active service.
    var previewServiceID: UUID?

    let displayName: String
    let businessName: String
    let timeZone: TimeZone
    let localization: AppLocalization
    /// The business region: the country "Where you work" starts with.
    let regionCode: String
    let firstWeekday: Int
    let professions: [ProfessionID]
    /// Her first profession's name in the app's language ("Esthetician"), for the suggestion card.
    let professionName: String?

    private let service: BookingSetupService
    private let servicesSource: (any AgendaRepository)?
    private let clipboard: any ClipboardWriting
    private let now: @Sendable () -> Date
    private let baseURL: URL
    private let copiedDuration: Duration
    private var copiedTask: Task<Void, Never>?

    init(
        service: BookingSetupService,
        profile: ProfessionalProfile?,
        services: (any AgendaRepository)? = nil,
        clipboard: any ClipboardWriting = SystemClipboard(),
        baseURL: URL = BookingLink.defaultBaseURL,
        copiedDuration: Duration = .seconds(2),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        servicesSource = services
        editor = BookingSetupEditor(service: service)
        availability = service.availability
        self.clipboard = clipboard
        self.baseURL = baseURL
        self.copiedDuration = copiedDuration
        self.now = now
        displayName = profile?.displayName ?? ""
        businessName = profile?.businessName ?? ""
        timeZone = profile.map { TimeZone(identifier: $0.timeZoneID) ?? .current } ?? .current
        localization = profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en
        regionCode = profile?.regionCode ?? Locale.current.region?.identifier ?? "US"
        firstWeekday = profile?.weekConfig.firstWeekday ?? Calendar.current.firstWeekday
        professions = profile?.professions ?? []
        let catalog = try? ProfessionCatalog.loadBundled(localization: localization)
        professionName = professions.first.flatMap { catalog?.entry(for: $0)?.name }
    }

    // MARK: - Reading

    var setup: BookingSetup { editor.setup }

    /// Her saved address on one line, for the "Where you work" row; nil until she saved one.
    var locationSummary: String? {
        setup.location.map(BusinessLocationFormat.oneLine).flatMap { $0.isEmpty ? nil : $0 }
    }

    var professionalName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    var pageState: BookingPageState {
        BookingPause.state(of: setup.page, now: now(), timeZone: timeZone)
    }

    var isAccepting: Bool { pageState == .accepting }

    /// The day a pause ends, when it has a return date.
    var returnDate: Date? {
        if case .paused(let until) = pageState { return until }
        return nil
    }

    var earliestReturnDate: Date {
        BookingPause.earliestReturnDate(now: now(), timeZone: timeZone)
    }

    /// Her booking link; nil until she chose an address.
    var link: BookingLink? {
        setup.slug.map { BookingLink(slug: $0, baseURL: baseURL) }
    }

    var showsSkeleton: Bool { isLoading && !hasLoaded }

    var saveErrorMessage: String? { editor.saveErrorMessage ?? availabilityErrorMessage }

    /// The values a menu offers, with the current one always included (a value from an older version stays selectable).
    func options(_ standard: [Int], including current: Int) -> [Int] {
        Set(standard + [current]).sorted()
    }

    // MARK: - Preview and suggestions (routine item 10)

    /// Her active services, in her order, for the preview's service menu.
    var previewableServices: [Service] {
        services.filter(\.isActive).sorted { $0.position < $1.position }
    }

    /// The sample day of "What clients see", from her current settings: recomputed on every change, on the phone.
    var slotPreview: SlotPreview? {
        SlotPreviewBuilder.preview(
            settings: availability, services: services, previewing: previewServiceID, now: now()
        )
    }

    /// The agenda values that suit her profession, when hers differ from them; nil once they match.
    var professionSuggestion: (profession: ProfessionID, defaults: ProfessionAgendaDefaults)? {
        guard let suggestion = ProfessionAgendaDefaults.suggestion(for: professions),
              !suggestion.defaults.matches(availability) else { return nil }
        return suggestion
    }

    /// Whether an advanced option (start times, compact day) is not at its default, so "More options" opens by itself.
    var hasAdvancedChanges: Bool {
        availability.effectiveSlotStep != FreeSlotsRequest.defaultStepMinutes || !availability.keepsDayCompact
    }

    /// "Use these": applies the suggested time between clients, start times and compact day. Hours stay hers.
    func useSuggestedDefaults() async {
        guard let suggestion = professionSuggestion else { return }
        await changeAvailability { $0 = suggestion.defaults.applied(to: $0) }
    }

    // MARK: - Loading

    /// Entry point for appearing and retrying; `loadAsync()` is what tests await.
    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            try await service.load(timeZoneID: timeZone.identifier)
            editor.adoptStored()
            availability = service.availability
            // The preview is a help, not the screen: services that cannot be read leave the 60-minute sample.
            if let servicesSource { services = (try? await servicesSource.services()) ?? services }
        } catch {
            errorMessage = String(
                localized: "bookingSetup.error.load",
                defaultValue: """
                We could not read your booking settings. Check that your iPhone is unlocked and try again.
                """
            )
        }
    }

    /// When the screen comes back into view from a policy screen: take what they stored.
    func appear() {
        editor.adoptStored()
        availability = service.availability
    }

    // MARK: - The page

    func setConfirmNewClients(_ value: Bool) {
        change { $0.page.confirmNewClients = value }
    }

    func setMaxGuests(_ value: Int) {
        let range = BookingPageSettings.guestRange
        let guests = min(max(value, range.lowerBound), range.upperBound)
        change { $0.page.maxGuests = guests }
    }

    /// Pauses bookings. `until` is the day she is back, or nil for no date.
    func pause(until: Date?) async {
        let current = now()
        let zone = timeZone
        await editor.apply { $0.page = BookingPause.pausing($0.page, until: until, now: current, timeZone: zone) }
    }

    func resume() async {
        await editor.apply { $0.page = BookingPause.resuming($0.page) }
    }

    /// Changes the return date of a pause that is already on; nil removes it.
    func setReturnDate(_ date: Date?) async {
        await pause(until: date)
    }

    // MARK: - Rules that live in her availability

    func setBuffer(_ minutes: Int) async {
        await changeAvailability { $0.bufferMinutes = minutes }
    }

    func setMinNoticeHours(_ hours: Int) async {
        await changeAvailability { $0.minNoticeHours = hours }
    }

    func setMaxDaysAhead(_ days: Int) async {
        await changeAvailability { $0.maxDaysAhead = days }
    }

    /// The grid of start times her page and her own suggestions offer (D56); 0 is "match the service".
    func setSlotStep(_ minutes: Int) async {
        await changeAvailability { $0.slotStepMinutes = minutes }
    }

    /// "Keep my day compact" (D56).
    func setCompactDay(_ isOn: Bool) async {
        await changeAvailability { $0.compactDay = isOn }
    }

    // MARK: - Link

    func copyLink() {
        guard let link else { return }
        clipboard.write(link.url.absoluteString)
        copiedLink = true
        copiedTask?.cancel()
        copiedTask = Task { [copiedDuration] in
            try? await Task.sleep(for: copiedDuration)
            guard !Task.isCancelled else { return }
            copiedLink = false
        }
    }

    func dismissSaveError() {
        editor.dismissSaveError()
        availabilityErrorMessage = nil
    }

    // MARK: - Private

    private func change(_ edit: @escaping (inout BookingSetup) -> Void) {
        Task { await editor.apply(edit) }
    }

    private func changeAvailability(_ edit: (inout AvailabilitySettings) -> Void) async {
        var updated = availability
        edit(&updated)
        guard updated != availability else { return }
        availability = updated
        availabilityErrorMessage = nil
        do {
            try await service.saveAvailability(updated)
        } catch {
            availability = service.availability
            availabilityErrorMessage = String(
                localized: "bookingSetup.error.save",
                defaultValue: "We could not save this change. Check that your iPhone has space and try again."
            )
        }
    }
}
