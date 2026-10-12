//
//  TreatmentFlowViewModel+Draft.swift
//  BelloHub
//

import Foundation

/// The draft: everything she writes or photographs is saved on its own, a moment after each change, as a draft record
/// in the vault (encrypted, on her iPhone and in her iCloud). Closing the app or the flow loses nothing; the draft is
/// on the client's timeline, on Home and in the alerts until she finalizes it. "Finalize record" is her decision and
/// starts the 24-hour lock. An empty draft is never stored, so opening and closing the flow leaves no trace.
extension TreatmentFlowViewModel {
    // MARK: - Opening

    /// Continues a stored record: its answers, its visit day and its photos.
    func open(_ record: TreatmentRecord) async {
        recordID = record.id
        savedRecord = record
        draft = TreatmentDraftLoader.draft(from: record, fields: reviewFields)
        performedAt = record.performedAt ?? appointment?.startsAt ?? record.createdAt
        aiAssisted = record.aiAssisted
        usedTranscript = record.source == .voice
        autosave = .saved(record.createdAt)
        guard let repository else { return }
        let stored = ((try? await repository.photos(for: clientID)) ?? [])
            .filter { $0.recordID == record.id }
            .sorted { $0.takenAt < $1.takenAt }
        var loaded: [FlowPhoto] = []
        for photo in stored {
            guard let data = try? await repository.photoData(id: photo.id) else { continue }
            loaded.append(FlowPhoto(photo: photo, data: data))
        }
        photos = loaded
    }

    /// Starts a new visit from the parts she chose of a past one (`VisitReuse`); nothing is saved until she changes
    /// something, and the result, reaction, photos and visit day always start fresh.
    func applyBase(_ source: TreatmentRecord, parts: Set<VisitReuse.Part>) {
        let empty = TreatmentRecord(id: recordID, clientID: clientID, serviceName: serviceName, createdAt: now(),
                                    status: .draft)
        let copied = VisitReuse.apply(parts, from: source, to: empty)
        let loaded = TreatmentDraftLoader.draft(from: copied, fields: reviewFields)
        for (key, value) in loaded.values where draft.value(for: key).isEmpty { draft.set(value, for: key) }
        draft.result = nil
        carriedFromBase = copied
    }

    // MARK: - Editing

    /// Sets one answer and saves the draft a moment later.
    func set(_ value: String, for key: String) {
        draft.set(value, for: key)
        draftChanged()
    }

    func setResult(_ result: RecordResult?) {
        draft.result = result
        draftChanged()
    }

    func setPerformedAt(_ date: Date) {
        performedAt = min(date, now())
        draftChanged()
    }

    /// For a visit with no appointment: the service that was done.
    func selectService(_ id: UUID?) {
        service = services.first { $0.id == id }
        nextWeeks = NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: service?.followUpWeeks)
        prefillAftercare()
        draftChanged()
    }

    // MARK: - Automatic save

    /// Called after every change on the form: saves the draft a moment later. A locked record is never touched (its
    /// fields read only), and nothing is stored before there is something worth keeping.
    func draftChanged() {
        guard loadState == .ready, !isLocked else { return }
        guard hasContent || savedRecord != nil else { return }
        autosave = .saving
        autosaveTask?.cancel()
        let delay = autosaveDelay
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.autosaveNow()
        }
    }

    /// Writes the draft now (the retry button, and leaving the flow).
    func autosaveNow() async {
        autosaveTask?.cancel()
        guard loadState == .ready, !isLocked, hasContent || savedRecord != nil else {
            if case .saving = autosave { autosave = .idle }
            return
        }
        let status: RecordStatus = isFinalized ? .finalized : .draft
        autosave = await persist(status: status) ? .saved(now()) : .failed
    }

    func retryAutosave() { Task { await autosaveNow() } }

    // MARK: - Finalizing

    /// "Finalize record": the draft becomes the record, its 24-hour lock starts, and the compact confirmation shows.
    /// Required fields of her template may stop it (never a draft save).
    func finalize() async {
        showsValidation = true
        guard canFinalize else { return }
        autosaveTask?.cancel()
        guard await persist(status: .finalized) else { return }
        autosave = .saved(now())
        markClosingDone()
        path = [.saved]
    }

    func finalizeTapped() { Task { await finalize() } }

    /// Deletes a draft she does not want, with its photos. A finalized record is never deleted here.
    func discardDraft() async -> Bool {
        autosaveTask?.cancel()
        guard !isFinalized else { return false }
        guard let repository, savedRecord != nil else {
            draft = TreatmentDraft()
            return true
        }
        do {
            try await repository.deleteDraft(id: recordID)
            savedRecord = nil
            photos = []
            draft = TreatmentDraft()
            autosave = .idle
            return true
        } catch {
            failure = .delete
            return false
        }
    }

    // MARK: - Private

    /// Builds the record from the form and writes it. The same id every time, so saving twice never makes two records.
    func persist(status: RecordStatus) async -> Bool {
        guard let repository, let client else { return false }
        isSaving = true
        failure = nil
        defer { isSaving = false }
        let context = TreatmentRecordBuilder.Context(
            clientID: client.id, appointmentID: savedRecord?.appointmentID ?? request.appointmentID ?? appointment?.id,
            serviceID: service?.id ?? savedRecord?.serviceID ?? request.serviceID, serviceName: serviceName,
            id: recordID, createdAt: savedRecord?.createdAt ?? now(), source: usedTranscript ? .voice : .manual,
            aiAssisted: aiAssisted, performedAt: performedAt, status: status,
            carried: savedRecord ?? carriedFromBase
        )
        let record = TreatmentRecordBuilder.build(draft: draft, fields: reviewFields, context: context, locale: locale)
        do {
            try await repository.save(record)
            // The repository decides the lock and the finalize time; read back what it stored.
            savedRecord = (try? await repository.record(id: record.id)) ?? record
            return true
        } catch {
            failure = .save
            return false
        }
    }

    /// Makes sure the draft exists before a photo points to it, so a photo is never tied to a record that is not
    /// there.
    func ensureStored() async -> Bool {
        if savedRecord != nil { return true }
        return await persist(status: .draft)
    }
}
