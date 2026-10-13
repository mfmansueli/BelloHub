//
//  NewAppointmentViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the New appointment sheet (3.1): who, what kind of visit, which service, add-ons and guests,
/// and when. It watches the warnings as she chooses (`SchedulingWarningEngine`) and books through
/// `AppointmentService`. **Warnings inform; the booking stays her decision.**
@MainActor
@Observable
final class NewAppointmentViewModel {
    // MARK: - What she chose

    private(set) var clientID: UUID?
    var searchText = ""
    var visitType = VisitType.treatment
    private(set) var serviceID: UUID?
    private(set) var addOnIDs: Set<UUID> = []
    private(set) var guestNames: [String] = []
    /// The day the time is on, as the start of the day in the business time zone.
    private(set) var day: Date
    private(set) var start: Date?

    // MARK: - What the screen shows

    private(set) var clients: [Client] = []
    private(set) var services: [Service] = []
    private(set) var addOns: [AddOn] = []
    private(set) var context = SchedulingContext.empty
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The first read failed; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// The client's health form and patch tests could not be read, so the warnings about them may be missing.
    private(set) var contextIsIncomplete = false
    private(set) var saveErrorMessage: String?
    private(set) var isSaving = false
    private(set) var didBook = false
    /// The client's exclusive manage link minted when booking if online booking is configured.
    private(set) var exclusiveManageLink: String?
    /// How the last "Send" on the confirmation screen ended; nil before she taps.
    private(set) var confirmationOutcome: MessageService.Outcome?

    let days: CalendarDays
    let timeZoneID: String
    private let appointmentService: AppointmentService
    let bookingSetup: BookingSetupService
    private let vault: VaultService
    private let profileService: ProfileService
    private let messages: MessageService
    private let clientLinks: ClientLinkService?
    private let loader: SchedulingContextLoader
    private let now: @Sendable () -> Date
    private var contextGeneration = 0

    init(
        clientID: UUID?, startsAt: Date?, timeZoneID: String, firstWeekday: Int = 2,
        appointments: AppointmentService, timeBlocks: TimeBlockService, bookingSetup: BookingSetupService,
        vault: VaultService, profileService: ProfileService? = nil, messages: MessageService? = nil,
        clientLinks: ClientLinkService? = nil,
        catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider(),
        localization: AppLocalization = .en, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let days = CalendarDays(timeZone: TimeZone(identifier: timeZoneID) ?? .current, firstWeekday: firstWeekday)
        self.days = days
        self.timeZoneID = timeZoneID
        appointmentService = appointments
        self.bookingSetup = bookingSetup
        self.vault = vault
        self.profileService = profileService ?? ProfileService(vault: vault)
        self.messages = messages ?? MessageService(vault: vault)
        self.clientLinks = clientLinks
        loader = SchedulingContextLoader(
            appointments: appointments, timeBlocks: timeBlocks, vault: vault, catalogProvider: catalogProvider,
            localization: localization
        )
        self.now = now
        self.clientID = clientID
        start = startsAt
        day = days.start(of: startsAt ?? now())
    }

    // MARK: - Reading

    /// Her hours, read in the zone this screen cuts its days in: a day chosen here gets that day's hours even when
    /// they were saved in another zone (`AvailabilitySettings.inTimeZone`).
    var availability: AvailabilitySettings { bookingSetup.availability.inTimeZone(days.calendar.timeZone) }

    var selectedClient: Client? { clients.first { $0.id == clientID } }

    var selectedService: Service? { services.first { $0.id == serviceID } }

    /// The clients the list shows: the chosen one first, then those that match the search, a handful at a time.
    var visibleClients: [Client] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = clients.filter {
            !$0.isArchived && (query.isEmpty || ClientSearch.matches($0, query: query, tags: []))
        }
        let chosen = matches.filter { $0.id == clientID }
        let others = matches.filter { $0.id != clientID }
        return Array((chosen + others).prefix(Self.visibleClientLimit))
    }

    static let visibleClientLimit = 6
    static let maximumGuests = 4

    var chosenAddOns: [AddOn] { addOns.filter { addOnIDs.contains($0.id) } }

    var totalMinutes: Int {
        guard let service = selectedService else { return 0 }
        return VisitDuration.totalMinutes(
            serviceMinutes: service.durationMinutes, addOnMinutes: chosenAddOns.map(\.minutes),
            guests: guestNames.count
        )
    }

    var endsAt: Date? {
        start.map { $0.addingTimeInterval(TimeInterval(totalMinutes * 60)) }
    }

    var exceedsMaximumDuration: Bool { VisitDuration.exceedsMaximum(totalMinutes) }

    var canAddGuest: Bool { guestNames.count < Self.maximumGuests }

    /// The free starts of the chosen day for this visit (D56: her slot interval, extra and processing time).
    var slotPlan: FreeSlotsPlan {
        guard totalMinutes > 0 else { return .empty }
        return OpenTimes.plan(on: day, request(duration: totalMinutes))
    }

    /// The times suggested first: with "Keep my day compact", the ones that leave no gap nobody can book.
    var slots: [Date] { slotPlan.recommended }

    /// The other free times, behind "Show all times".
    var moreSlots: [Date] { slotPlan.more }

    var warnings: [SchedulingWarning] {
        guard let start, let service = selectedService, totalMinutes > 0 else { return [] }
        return SchedulingWarningEngine.warnings(for: SchedulingWarningInput(
            interval: DateInterval(start: start, duration: TimeInterval(totalMinutes * 60)),
            settings: availability, appointments: context.appointments, blocks: context.blocks, service: service,
            clientID: clientID, clientAppointments: context.clientAppointments, form: context.form,
            catalog: context.catalog, patchTests: context.patchTests, now: now(), services: services
        ))
    }

    /// A warning about the time itself: the primary button then says "Book anyway".
    var hasScheduleConflict: Bool { warnings.contains { $0.isScheduleConflict } }

    var canBook: Bool {
        clientID != nil && selectedService != nil && start != nil && !exceedsMaximumDuration && !isSaving
    }

    /// The name of a client by id, for a warning that names the visit it clashes with.
    func clientName(for appointmentID: UUID) -> String? {
        guard let visit = context.appointments.first(where: { $0.id == appointmentID }) else { return nil }
        return clients.first { $0.id == visit.clientID }?.name
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
        guard let repository = vault.repository else {
            errorMessage = Self.unavailableMessage
            return
        }
        do {
            clients = try await repository.allClients()
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            services = try await repository.services().filter(\.isActive)
            addOns = try await repository.addOns().filter(\.isOffered)
            try await bookingSetup.load(timeZoneID: timeZoneID)
            if profileService.profile == nil { await profileService.load() }
            let appLocale = profileService.profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en
            try? await bookingSetup.loadQuickReplies(localization: appLocale)
        } catch {
            errorMessage = Self.unavailableMessage
            return
        }
        if serviceID == nil { serviceID = services.first?.id }
        await refreshContext()
    }

    static var unavailableMessage: String {
        String(interface: LocalizedStringResource(
            "newAppointment.error.load",
            defaultValue: "We could not read your clients and services. Check that your iPhone is unlocked."
        ))
    }

    // MARK: - Booking

    /// Books the visit. Returns true when it is stored.
    @discardableResult
    func bookAsync() async -> Bool {
        guard canBook, let clientID, let service = selectedService, let start else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }
        let linked = AppointmentBuilder.visitToCheck(among: context.clientAppointments, before: start)
        let appointment = AppointmentBuilder.appointment(
            from: AppointmentBuilder.Choice(
                clientID: clientID, service: service, visitType: visitType, addOns: chosenAddOns,
                guestNames: guestNames, startsAt: start, linkedAppointmentID: linked?.id
            ),
            now: now()
        )
        do {
            try await appointmentService.book(appointment)
            if let client = selectedClient {
                let localeID = profileService.profile?.appLocaleID
                let appLocale = localeID.flatMap { AppLocalization(rawValue: $0) } ?? .en
                if let link = await clientLinks?.registerManualBooking(
                    appointment: appointment,
                    client: client,
                    serviceName: service.name,
                    timeZoneID: timeZoneID,
                    locale: appLocale.rawValue
                ) {
                    exclusiveManageLink = link.url.absoluteString
                }
            }
            didBook = true
            return true
        } catch {
            saveErrorMessage = String(interface: LocalizedStringResource(
                "newAppointment.error.save",
                defaultValue: "We could not save this appointment. Nothing was changed. Try again."
            ))
            return false
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    /// Selects a client who was just created through the "New client" sheet.
    func clientWasAdded(_ id: UUID) async {
        if let repository = vault.repository, let loaded = try? await repository.allClients() {
            clients = loaded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        clientID = id
        await refreshContext()
    }

    // MARK: - Private

    private func request(duration: Int) -> OpenTimes.Request {
        OpenTimes.Request(
            durationMinutes: duration, settings: availability, appointments: context.appointments,
            blocks: context.blocks, now: now(), services: services,
            timing: selectedService?.visitTiming ?? .noExtraTime
        )
    }

    /// Reads the visits around the chosen day and everything about the client. A newer call wins over an older one
    /// that finishes late.
    private func refreshContext() async {
        contextGeneration += 1
        let generation = contextGeneration
        let interval = days.interval(of: day)
        let range = DateInterval(start: days.adding(days: -1, to: day), end: days.adding(days: 1, to: interval.end))
        do {
            let loaded = try await loader.load(range: range, clientID: clientID)
            guard generation == contextGeneration else { return }
            context = loaded
            contextIsIncomplete = false
        } catch {
            guard generation == contextGeneration else { return }
            // Keep the surroundings if they can be read: the time warnings still work.
            var partial = SchedulingContext.empty
            partial.catalog = context.catalog
            if let near = try? await loader.surroundings(of: range) {
                partial.appointments = near.appointments
                partial.blocks = near.blocks
            }
            context = partial
            contextIsIncomplete = clientID != nil
        }
    }
}

// MARK: - Choosing

extension NewAppointmentViewModel {
    func selectClient(_ id: UUID) {
        guard id != clientID else { return }
        clientID = id
        Task { await refreshContext() }
    }

    func selectService(_ id: UUID) {
        serviceID = id
    }

    func toggleAddOn(_ id: UUID) {
        if addOnIDs.contains(id) { addOnIDs.remove(id) } else { addOnIDs.insert(id) }
    }

    func addGuest() {
        guard canAddGuest else { return }
        guestNames.append("")
    }

    func setGuestName(_ name: String, at index: Int) {
        guard guestNames.indices.contains(index) else { return }
        guestNames[index] = name
    }

    func removeGuest(at index: Int) {
        guard guestNames.indices.contains(index) else { return }
        guestNames.remove(at: index)
    }

    /// Moves to another day and forgets the chosen time (a time of one day means little on another).
    func selectDay(_ date: Date) {
        let newDay = days.start(of: date)
        guard newDay != day else { return }
        day = newDay
        start = nil
        Task { await refreshContext() }
    }

    func selectStart(_ date: Date) {
        start = date
    }

    /// A time typed with the picker: `minutes` after midnight on the chosen day.
    func selectTime(minutes: Int) {
        start = days.date(on: day, minutes: minutes)
    }
}

// MARK: - Confirmation Message

extension NewAppointmentViewModel {
    /// Builds the confirmation message for the booked appointment, including client name, service, date, time,
    /// full address and booking link.
    func confirmationMessageText(formatters: Formatters) -> String {
        guard let client = selectedClient, let service = selectedService, let start else { return "" }
        let localization = profileService.profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en
        let confirmReply = bookingSetup.quickReplies.first { $0.builtInKey == BuiltInQuickReply.confirm.rawValue }
        let link = exclusiveManageLink ?? bookingSetup.setup.slug.map { BookingLink(slug: $0).messageText }
        let location = bookingSetup.setup.location
        let profile = profileService.profile
        let businessName = profile?.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let businessDisplay = (businessName?.isEmpty == false ? businessName : profile?.displayName) ?? ""
        let input = BookingConfirmationText.Input(
            client: client, serviceName: service.name, startsAt: start, link: link,
            location: location, businessName: businessDisplay, confirmReply: confirmReply,
            localization: localization, formatters: formatters
        )
        return BookingConfirmationText.text(for: input)
    }

    /// Opens WhatsApp with the confirmation message ready to send to the client.
    func sendConfirmationWhatsApp(messageText: String) async {
        guard let client = selectedClient else { return }
        confirmationOutcome = await messages.send(
            text: messageText, to: client.id, phoneE164: client.phoneE164,
            template: BuiltInQuickReply.confirm.rawValue, preferred: .whatsapp, now: now()
        )
    }

    /// Opens Messages (SMS / iMessage) with the confirmation message ready to send to the client.
    func sendConfirmationSMS(messageText: String) async {
        guard let client = selectedClient else { return }
        confirmationOutcome = await messages.send(
            text: messageText, to: client.id, phoneE164: client.phoneE164,
            template: BuiltInQuickReply.confirm.rawValue, preferred: .messages, now: now()
        )
    }
}
