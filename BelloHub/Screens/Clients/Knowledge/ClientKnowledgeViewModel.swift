//
//  ClientKnowledgeViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of "client knowledge" (4.4): the private note and the three lists she keeps about a client.
/// Nothing is saved until Done, which goes through the registration gate like every client write (it returns
/// `updated` and never counts). A half-typed entry is added by Done rather than lost.
@MainActor
@Observable
final class ClientKnowledgeViewModel {
    let clientID: UUID
    private(set) var original: Client?
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var isFinished = false
    /// "Important to know": her private note, as typed.
    var note = ""
    private(set) var lists: [KnowledgeSection: [String]] = [:]
    /// What is typed in each "add" field and not added yet.
    var pending: [KnowledgeSection: String] = [:]
    /// The last "add" that was refused because the list already says it, for the screen to point at.
    private(set) var duplicateIn: KnowledgeSection?

    private let registrar: any ClientRegistering
    private let vault: VaultService

    init(clientID: UUID, registrar: any ClientRegistering, vault: VaultService) {
        self.clientID = clientID
        self.registrar = registrar
        self.vault = vault
    }

    // MARK: - Derived

    func entries(in section: KnowledgeSection) -> [String] { lists[section] ?? [] }

    /// Her first name for the sentence under the title: "What you want to remember about Ana".
    var firstName: String {
        original?.name.split(separator: " ").first.map(String.init) ?? ""
    }

    /// Something changed, including a half-typed entry: the "discard changes?" question.
    var isDirty: Bool {
        guard let original else { return false }
        return !pendingEntries.isEmpty || noteValue != original.importantNote
            || KnowledgeSection.allCases.contains { entries(in: $0) != $0.entries(of: original) }
    }

    // MARK: - Loading

    func load() async {
        guard let repository = vault.repository else { return fail() }
        do {
            guard let client = try await repository.client(id: clientID) else {
                isMissing = true
                isLoading = false
                return
            }
            original = client
            note = client.importantNote ?? ""
            lists = Dictionary(uniqueKeysWithValues: KnowledgeSection.allCases.map { ($0, $0.entries(of: client)) })
            isLoading = false
        } catch {
            fail()
        }
    }

    /// Fire-and-forget entry point for the retry button after a failed load.
    func retry() {
        isLoading = true
        errorMessage = nil
        Task { await load() }
    }

    // MARK: - Editing

    /// Adds what is typed in `section`'s field, if it says something new.
    func add(to section: KnowledgeSection) {
        switch KnowledgeListRules.adding(pending[section] ?? "", to: entries(in: section)) {
        case .added(let updated):
            lists[section] = updated
            pending[section] = ""
            duplicateIn = nil
        case .empty:
            pending[section] = ""
        case .duplicate:
            duplicateIn = section
        }
    }

    /// Adds a saved option (or one she just created) to `section`; the same words already there are not repeated.
    /// A saved word is offered only while the list does not already say it, by the list's own rule (case and accents
    /// ignored), so a chip never shows for something a tap would refuse.
    func offers(_ name: String, in section: KnowledgeSection) -> Bool {
        if case .added = KnowledgeListRules.adding(name, to: entries(in: section)) { return true }
        return false
    }

    func add(_ entry: String, to section: KnowledgeSection) {
        if case .added(let updated) = KnowledgeListRules.adding(entry, to: entries(in: section)) {
            lists[section] = updated
            duplicateIn = nil
        }
    }

    func remove(at offsets: IndexSet, from section: KnowledgeSection) {
        lists[section] = KnowledgeListRules.removing(offsets, from: entries(in: section))
    }

    func move(from source: IndexSet, to destination: Int, in section: KnowledgeSection) {
        lists[section] = KnowledgeListRules.moving(source, to: destination, in: entries(in: section))
    }

    // MARK: - Saving

    /// Fire-and-forget entry point for Done (CLAUDE.md section 2).
    func done() {
        Task { await doneAsync() }
    }

    func doneAsync() async {
        guard !isSaving, var client = original else { return }
        for section in KnowledgeSection.allCases where !(pending[section] ?? "").isEmpty { add(to: section) }
        for section in KnowledgeSection.allCases { section.setEntries(entries(in: section), on: &client) }
        client.importantNote = noteValue
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            switch try await registrar.register(client) {
            case .updated, .registered: isFinished = true
            case .duplicate, .needsSubscription: errorMessage = String(interface: LocalizedStringResource(
                "clientKnowledge.error.save"
            ))
            }
        } catch {
            errorMessage = String(interface: LocalizedStringResource("clientKnowledge.error.save"))
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    private var noteValue: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var pendingEntries: [String] {
        pending.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("clientKnowledge.error.load"))
    }
}
