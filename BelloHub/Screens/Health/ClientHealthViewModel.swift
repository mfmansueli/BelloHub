//
//  ClientHealthViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// Screen 4.5: what one client told the professional about her health, her consent records (D55) and the patch
/// tests. It loads from the vault, derives what the screen shows with the pure rules, and owns the three sheets
/// (fill the form, record a patch test, add or edit a consent) so their lifetime is the screen's.
@MainActor
@Observable
final class ClientHealthViewModel {
    let clientID: UUID
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var client: Client?
    private(set) var forms: [HealthForm] = []
    private(set) var consents: [ConsentRecord] = []
    private(set) var patchTests: [PatchTest] = []
    private(set) var templates: [HealthFormTemplate] = []
    private(set) var catalog: HealthFormCatalog?
    /// Her visits, newest first, so a document can say which visit it belongs to (optional).
    private(set) var visits: [TreatmentRecord] = []
    /// The sheets. Setting one to nil closes it; the view reloads when a sheet goes away.
    var fillSheet: HealthFormViewModel?
    var patchSheet: PatchTestViewModel?
    var consentSheet: ConsentRecordViewModel?

    private let repository: (any HealthRepository)?
    private let records: (any TreatmentRepository)?
    private let profile: ProfileService
    private let catalogProvider: any HealthFormCatalogProviding
    private let photos: any PhotoProcessing
    private let files: any ConsentDocumentReading
    private let localization: AppLocalization
    private let locale: Locale
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private var isPreparingSheet = false

    init(
        clientID: UUID,
        repository: (any HealthRepository)?,
        records: (any TreatmentRepository)? = nil,
        profile: ProfileService,
        catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider(),
        photos: any PhotoProcessing = ImageIOPhotoProcessing(),
        files: any ConsentDocumentReading = SystemConsentDocumentReader(),
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.clientID = clientID
        self.repository = repository
        self.records = records
        self.profile = profile
        self.catalogProvider = catalogProvider
        self.photos = photos
        self.files = files
        self.locale = locale
        self.localization = AppLocalization(locale: locale)
        self.now = now
        self.makeID = makeID
    }

    // MARK: - Loading

    /// Fire-and-forget entry point (a retry button, a sheet that closed); `load()` is what `.refreshable` awaits.
    func reload() {
        Task { await load() }
    }

    /// Reads the client, her forms, consents and patch tests, the form versions and the catalog. A second call while
    /// one is running does nothing. A failure keeps what was already on screen.
    func load() async {
        guard !isLoading else { return }
        guard let repository else {
            errorMessage = String(interface: LocalizedStringResource("health.error.load"))
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let loadedClient = try await repository.client(id: clientID) else {
                errorMessage = String(interface: LocalizedStringResource("health.error.load"))
                return
            }
            let loadedCatalog = try catalogProvider.catalog(for: localization)
            forms = try await repository.healthForms(for: clientID)
            consents = try await repository.consents(for: clientID)
            patchTests = try await repository.patchTests(for: clientID)
            templates = try await repository.healthFormTemplates()
            // A visit list that cannot be read only costs the optional link, never the screen.
            // Finalized visits only: a draft may still be discarded, which would leave the document pointing nowhere.
            visits = ((try? await records?.records(for: clientID)) ?? [])
                .filter { !$0.isDraft }
                .sorted { ($0.performedAt ?? $0.createdAt) > ($1.performedAt ?? $1.createdAt) }
            client = loadedClient
            catalog = loadedCatalog
            hasLoaded = true
        } catch {
            errorMessage = String(interface: LocalizedStringResource("health.error.load"))
        }
    }

    // MARK: - What the screen shows

    var formatters: Formatters {
        let zone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: zone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }

    var latestForm: HealthForm? { HealthFormTemplateRules.latestForm(in: forms) }

    var currentTemplate: HealthFormTemplate? { HealthFormTemplateRules.current(of: templates) }

    /// "Ask again every": the professional's setting, or the default until she has edited the form.
    var reviewMonths: Int { currentTemplate?.reviewEveryMonths ?? HealthFormTemplateRules.defaultReviewMonths }

    var reviewStatus: HealthReviewStatus? {
        guard let form = latestForm else { return nil }
        return HealthFormTemplateRules.reviewStatus(
            signedAt: form.signedAt, months: reviewMonths, now: now(), calendar: formatters.calendar
        )
    }

    /// The first name, for "Reported by Ana".
    var clientFirstName: String {
        client?.name.split(separator: " ").first.map(String.init) ?? client?.name ?? ""
    }

    /// The rows of the latest form, read against the questions of the version it was signed on.
    var answerRows: [HealthAnswerSummary.Row] {
        guard let form = latestForm, let catalog else { return [] }
        let template = HealthFormTemplateRules.template(forVersion: form.formVersion, in: templates)
        let labels = HealthAnswerSummary.Labels(
            yes: text("health.answer.yes"), no: text("health.answer.no"), none: text("health.answer.none"),
            notAnswered: text("health.answer.notAnswered")
        )
        let formatters = formatters
        return HealthAnswerSummary.rows(
            form: form, template: template, catalog: catalog, labels: labels, list: formatters.list
        )
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }

    // MARK: - Sheets

    /// Opens the health form sheet. The template it asks is stored first (version 1 on the first use), so a form
    /// signed on it can always find its questions again.
    func startFilling() {
        Task { await startFillingAsync() }
    }

    func startFillingAsync() async {
        guard let client, let catalog, let repository, fillSheet == nil, !isPreparingSheet else { return }
        isPreparingSheet = true
        defer { isPreparingSheet = false }
        do {
            let template = try await repository.currentHealthFormTemplate(
                catalog: catalog, professions: profile.profile?.professions ?? [], now: now()
            )
            if !templates.contains(where: { $0.version == template.version }) { templates.append(template) }
            fillSheet = HealthFormViewModel(
                client: client, template: template, catalog: catalog, repository: repository, now: now, makeID: makeID
            )
        } catch {
            errorMessage = String(interface: LocalizedStringResource("health.error.load"))
        }
    }

    func startPatchTest() {
        guard let repository, patchSheet == nil else { return }
        patchSheet = PatchTestViewModel(clientID: clientID, repository: repository, now: now, makeID: makeID)
    }

    /// A new consent record (D55): the sheet starts signed, dated today.
    func startConsent() {
        guard let repository, consentSheet == nil else { return }
        consentSheet = ConsentRecordViewModel(
            clientID: clientID, repository: repository, visits: visits, photos: photos, files: files, now: now,
            makeID: makeID
        )
    }

    /// Edits an existing consent record in the same sheet.
    func open(_ consent: ConsentRecord) {
        guard let repository, consentSheet == nil else { return }
        consentSheet = ConsentRecordViewModel(
            clientID: clientID, existing: consent, repository: repository, visits: visits, photos: photos,
            files: files, now: now, makeID: makeID
        )
    }
}
