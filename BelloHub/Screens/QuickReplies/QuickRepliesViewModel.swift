//
//  QuickRepliesViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Quick replies (6.9): the list of her ready-made messages and adding, editing, putting back and
/// deleting them, with a preview of each filled in for an example client. Reads and writes go through
/// `BookingSetupService`; the rules are `QuickReplyRules`' and the filling in is `QuickReplyRenderer`'s.
@MainActor
@Observable
final class QuickRepliesViewModel {
    private(set) var replies: [QuickReply]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The replies could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it and the list stays as it was.
    private(set) var saveErrorMessage: String?

    let localization: AppLocalization
    private let service: BookingSetupService
    private let timeZone: TimeZone
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(
        service: BookingSetupService,
        profile: ProfessionalProfile?,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.service = service
        self.now = now
        self.makeID = makeID
        replies = service.quickReplies
        localization = profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en
        timeZone = profile.map { TimeZone(identifier: $0.timeZoneID) ?? .current } ?? .current
    }

    // MARK: - Reading

    /// Whether to draw placeholder rows: the first read is running and there is nothing to show yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded && replies.isEmpty }

    func issue(title: String, text: String) -> QuickReplyIssue? {
        QuickReplyRules.issue(title: title, text: text)
    }

    func isEdited(_ reply: QuickReply) -> Bool {
        QuickReplyRules.isEdited(reply, in: localization)
    }

    func reply(id: UUID) -> QuickReply? {
        replies.first { $0.id == id }
    }

    /// The words in curly braces in `text` that are not filled in.
    func unknownWords(in text: String) -> [String] {
        QuickReplyRenderer.unknownWords(in: text)
    }

    /// `text` as it would read for an example client, in the business language: what the preview shows.
    func preview(of text: String) -> String {
        let formatters = Formatters(locale: localization.locale, timeZone: timeZone, currencyCode: "EUR")
        return QuickReplyRenderer.render(
            text, values: sampleValues, formatters: formatters, isolates: localization.isRightToLeft
        )
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
            try await service.loadQuickReplies(localization: localization)
            replies = service.quickReplies
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "quickReplies.error.load",
                defaultValue: "We could not read your quick replies. Check that your iPhone is unlocked and try again."
            ))
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    /// Adds a reply of her own. Returns it, or nil when it was not valid or could not be saved.
    func add(title: String, text: String) async -> QuickReply? {
        guard let reply = QuickReplyRules.making(
            title: title, text: text, among: replies, id: makeID(), now: now()
        ) else { return nil }
        return await store(reply) ? reply : nil
    }

    /// Saves a new name and text for `reply`. Returns the saved reply, or nil.
    func save(_ reply: QuickReply, title: String, text: String) async -> QuickReply? {
        guard let updated = QuickReplyRules.updating(reply, title: title, text: text, now: now()) else { return nil }
        return await store(updated) ? updated : nil
    }

    /// Puts a built-in reply back as the catalog has it. Returns it, or nil for one she wrote or on failure.
    func resetToOriginal(_ reply: QuickReply) async -> QuickReply? {
        guard let original = QuickReplyRules.original(of: reply, in: localization, now: now()) else { return nil }
        return await store(original) ? original : nil
    }

    /// Deletes one of her own replies. A built-in one cannot be deleted. Returns whether it was.
    @discardableResult
    func delete(_ reply: QuickReply) async -> Bool {
        guard reply.builtIn == nil else { return false }
        saveErrorMessage = nil
        do {
            try await service.deleteQuickReply(id: reply.id)
            replies = service.quickReplies
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    // MARK: - Private

    private func store(_ reply: QuickReply) async -> Bool {
        saveErrorMessage = nil
        do {
            try await service.saveQuickReply(reply)
            replies = service.quickReplies
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// An example client: her first name, a service, the day after tomorrow at 15:00 and her link.
    private var sampleValues: QuickReplyValues {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now())) ?? now()
        let visit = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: day) ?? day
        let link = BookingLink(slug: service.setup.slug ?? "maria").messageText
        return QuickReplyValues(
            name: string("quickReplies.sample.name", default: "Ana"),
            service: string("quickReplies.sample.service", default: "Glow Facial"),
            startsAt: visit, link: link
        )
    }

    private func string(_ key: StaticString, default value: String.LocalizationValue) -> String {
        var resource = LocalizedStringResource(key, defaultValue: value)
        resource.locale = localization.locale
        return String(localized: resource)
    }

    private static var saveFailure: String {
        String(interface: LocalizedStringResource(
            "bookingSetup.error.save",
            defaultValue: "We could not save this change. Check that your iPhone has space and try again."
        ))
    }
}
