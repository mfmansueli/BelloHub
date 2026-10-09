//
//  ShareLinkViewModel.swift
//  BelloHub
//

import CoreGraphics
import Foundation
import Observation

/// State and actions of Share your link (6.8): her address (typed, suggested, checked and saved), the link, its QR
/// code and the texts she copies. Nothing is published here: the address is her choice, the server confirms it when
/// she goes online (S8), and until then the screen says so instead of pretending the link works.
@MainActor
@Observable
final class ShareLinkViewModel {
    /// Which copy button just worked, so it can say "Copied" for a moment.
    enum Copied: Equatable {
        case link
        case instagram
        case whatsApp
    }

    /// What she typed in the address field, always already clean (lowercase, no accents, hyphens for spaces).
    private(set) var draft: String
    private(set) var status = AddressStatus.idle
    private(set) var copied: Copied?
    private(set) var isSavingAddress = false
    /// The QR code of the saved link, drawn once per address (making one is not free), or nil without an address.
    private(set) var qrImage: CGImage?

    let editor: BookingSetupEditor
    let suggestions: [String]
    let localization: AppLocalization
    let professionalName: String

    private let booking: any BookingRepository
    private let clipboard: any ClipboardWriting
    private let baseURL: URL
    private let debounce: Duration
    private let copiedDuration: Duration
    private var checkTask: Task<Void, Never>?
    private var copiedTask: Task<Void, Never>?

    init(
        editor: BookingSetupEditor,
        displayName: String,
        businessName: String,
        localization: AppLocalization,
        booking: any BookingRepository = OfflineBookingRepository(),
        clipboard: any ClipboardWriting = SystemClipboard(),
        baseURL: URL = BookingLink.defaultBaseURL,
        debounce: Duration = .milliseconds(400),
        copiedDuration: Duration = .seconds(2)
    ) {
        self.editor = editor
        self.localization = localization
        self.booking = booking
        self.clipboard = clipboard
        self.baseURL = baseURL
        self.debounce = debounce
        self.copiedDuration = copiedDuration
        professionalName = displayName.split(separator: " ").first.map(String.init) ?? displayName
        suggestions = BookingSlug.suggestions(displayName: displayName, businessName: businessName)
        draft = editor.setup.slug ?? ""
        refreshQR()
    }

    // MARK: - Reading

    /// The address she saved, as a link; nil until she saved one.
    var savedLink: BookingLink? {
        editor.setup.slug.map { BookingLink(slug: $0, baseURL: baseURL) }
    }

    /// The host that stands in front of the field (`bellohub.app`).
    var host: String {
        BookingLink(slug: "", baseURL: baseURL).host
    }

    /// The texts she shares, for the saved link; nil until she saved an address.
    var texts: ShareTexts? {
        savedLink.map {
            ShareTexts(localization: localization, professionalName: professionalName, displayLink: $0.display)
        }
    }

    /// Whether the text in the field can be saved: valid, different from what is saved, and not known to be taken.
    var canSaveAddress: Bool {
        guard BookingSlug.validate(draft) == nil, draft != editor.setup.slug else { return false }
        switch status {
        case .taken, .reserved, .invalid, .checking: return false
        case .idle, .available, .unchecked: return true
        }
    }

    /// The saved address is the one in the field: the Save button turns into "Saved".
    var isAddressSaved: Bool {
        editor.setup.slug != nil && editor.setup.slug == draft
    }

    var errorMessage: String? { editor.saveErrorMessage }

    // MARK: - Address

    func appear() {
        editor.adoptStored()
        if draft.isEmpty, let slug = editor.setup.slug { draft = slug }
        refreshQR()
    }

    /// Called as she types: cleans the text, and checks it after a short pause.
    func updateDraft(_ raw: String) {
        let cleaned = BookingSlug.sanitizedWhileTyping(raw)
        draft = cleaned
        checkTask?.cancel()
        guard !cleaned.isEmpty else {
            status = .idle
            return
        }
        if let issue = BookingSlug.validate(cleaned) {
            // A trailing hyphen is how she separates words: not an error while she may still be typing.
            status = issue == .hyphenEdges && cleaned.hasSuffix("-") ? .idle : .invalid(issue)
            return
        }
        status = .checking
        checkTask = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await checkAddress(cleaned)
        }
    }

    func useSuggestion(_ slug: String) {
        updateDraft(slug)
    }

    /// Asks the server whether `slug` is free. Used by the typing pause and by tests.
    func checkAddress(_ slug: String) async {
        do {
            let result = try await booking.isSlugAvailable(slug)
            guard slug == draft else { return }
            switch result {
            case .available: status = .available
            case .taken: status = .taken
            case .reserved: status = .reserved
            case .invalid: status = BookingSlug.validate(slug).map(AddressStatus.invalid) ?? .reserved
            }
        } catch BookingRepositoryError.notPublishedYet {
            guard slug == draft else { return }
            status = .unchecked
        } catch {
            guard slug == draft else { return }
            // The network failed: the address is valid, it just could not be checked.
            status = .unchecked
        }
    }

    /// Saves the address in the field. Returns whether it was saved.
    @discardableResult
    func saveAddress() async -> Bool {
        guard canSaveAddress, !isSavingAddress else { return false }
        isSavingAddress = true
        defer { isSavingAddress = false }
        let slug = draft
        let saved = await editor.apply { $0.slug = slug }
        refreshQR()
        return saved
    }

    func dismissError() {
        editor.dismissSaveError()
    }

    // MARK: - Copying

    func copyLink() {
        guard let link = savedLink else { return }
        copy(link.url.absoluteString, as: .link)
    }

    func copyInstagram() {
        guard let text = texts?.instagramBio else { return }
        copy(text, as: .instagram)
    }

    func copyWhatsApp() {
        guard let text = texts?.whatsAppGreeting else { return }
        copy(text, as: .whatsApp)
    }

    // MARK: - Private

    private func refreshQR() {
        qrImage = savedLink.flatMap { QRCodeRenderer.image(for: $0.url.absoluteString) }
    }

    private func copy(_ text: String, as kind: Copied) {
        clipboard.write(text)
        copied = kind
        copiedTask?.cancel()
        copiedTask = Task { [copiedDuration] in
            try? await Task.sleep(for: copiedDuration)
            guard !Task.isCancelled else { return }
            copied = nil
        }
    }
}
