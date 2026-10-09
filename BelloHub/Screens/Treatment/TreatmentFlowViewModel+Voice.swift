//
//  TreatmentFlowViewModel+Voice.swift
//  BelloHub
//

import Foundation

/// The voice path: asking whether dictation is possible, listening, handing the transcript to the structuring
/// technology and reading what comes back. Both technologies sit behind protocols (D53), so with the v1 defaults the
/// first answer is "not available yet" and this file never runs past it.
extension TreatmentFlowViewModel {
    /// What the first screen offers.
    var registerOffer: VoiceFlowRules.Offer {
        VoiceFlowRules.offer(for: voiceAvailability ?? .notAvailableYet)
    }

    var listeningPhase: VoiceFlowRules.Phase { VoiceFlowRules.phase(elapsed: elapsed) }

    /// The language she dictates in: her business language.
    var voiceLocale: Locale {
        AppLocalization(rawValue: profile.profile?.appLocaleID ?? "")?.locale ?? locale
    }

    func refreshVoiceAvailability() async {
        voiceAvailability = await voice.availability(for: voiceLocale)
        structuringAvailable = await structuring.isAvailable(for: voiceLocale)
    }

    // MARK: - Listening

    /// Starts listening and opens the listening screen. Does nothing unless dictation is available.
    func startListening() {
        guard !isListening, voiceAvailability == .available else { return }
        do {
            let stream = try voice.start(locale: voiceLocale)
            transcript = ""
            elapsed = 0
            heardNothing = false
            isListening = true
            startedAt = now()
            path.append(.listening)
            listenTask = Task { [weak self] in
                for await text in stream {
                    guard let self, !Task.isCancelled else { return }
                    self.transcript = text
                }
            }
            tickTask = Task { [weak self] in await self?.tick() }
        } catch {
            voiceAvailability = .notAvailableYet
        }
    }

    /// Stops listening and decides where the words go: organized by the technology, into the form as notes, or
    /// nowhere when nothing was heard.
    func finishListening() async {
        guard isListening else { return }
        isListening = false
        listenTask?.cancel()
        tickTask?.cancel()
        let final = await voice.stop()
        if VoiceFlowRules.hasContent(final) { transcript = final }
        switch VoiceFlowRules.afterListening(transcript: transcript, structuringAvailable: structuringAvailable) {
        case .nothingHeard:
            heardNothing = true
            path.removeAll { $0 == .listening }
        case .organize:
            replaceTop(with: .organizing)
            organize()
        case .formWithTranscriptAsNotes:
            applyTranscriptAsNotes()
            replaceTop(with: .form)
        }
    }

    func finishListeningTapped() { Task { await finishListening() } }

    /// Cancel on the listening screen: stop, forget the words, back to the first screen.
    func cancelListening() {
        isListening = false
        listenTask?.cancel()
        tickTask?.cancel()
        transcript = ""
        path.removeAll()
        Task { _ = await voice.stop() }
    }

    // MARK: - Organizing

    /// Hands the transcript to the structuring technology. The result becomes proposals, never a record.
    func organize() {
        organizeTask?.cancel()
        failure = nil
        let transcript = transcript
        let fields = TreatmentFormFields.structuringFields(from: reviewFields)
        organizeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let draft = try await structuring.structure(transcript: transcript, fields: fields, locale: voiceLocale)
                guard !Task.isCancelled else { return }
                receive(draft)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                failure = .organize
            }
        }
    }

    /// Cancel on the organizing screen: her words stay as notes in the form, so nothing she dictated is lost.
    func cancelOrganizing() {
        organizeTask?.cancel()
        failure = nil
        applyTranscriptAsNotes()
        replaceTop(with: .form)
    }

    func receive(_ result: StructuredRecordDraft) {
        let found = ReviewMerge.proposals(from: result, fields: reviewFields, locale: locale)
        proposals = found.items
        rejectedCount = found.rejectedCount
        if found.items.isEmpty {
            // Nothing usable came back: the form, with her words as notes, is the honest next step.
            failure = .organize
        } else {
            replaceTop(with: .review)
        }
    }

    // MARK: - Private

    /// Counts seconds while listening and stops by itself at the hard limit.
    private func tick() async {
        while !Task.isCancelled, isListening {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, isListening else { return }
            elapsed = now().timeIntervalSince(startedAt ?? now())
            if listeningPhase == .stopNow { await finishListening() }
        }
    }
}
