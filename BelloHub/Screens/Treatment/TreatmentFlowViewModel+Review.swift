//
//  TreatmentFlowViewModel+Review.swift
//  BelloHub
//

import Foundation

/// The review step (5.4): she decides on every proposed field, and only then does anything go into the form. The gate
/// itself is `ReviewMerge`; this file keeps the cards' state and hands the kept answers to the draft.
extension TreatmentFlowViewModel {
    var isReviewComplete: Bool { ReviewMerge.isComplete(proposals) }

    var pendingCount: Int { proposals.filter(\.isPending).count }

    /// The fields the technology left empty, which the review says stay empty.
    var notMentioned: [TreatmentFormField] {
        ReviewMerge.notMentioned(proposals, fields: reviewFields)
    }

    func accept(_ key: String) { decide(key, .accepted) }

    func drop(_ key: String) { decide(key, .dropped) }

    func edit(_ key: String, to text: String) { decide(key, .edited(text)) }

    func acceptAll() {
        for index in proposals.indices where proposals[index].isPending { proposals[index].decision = .accepted }
    }

    /// Back to undecided, for a card she tapped by mistake.
    func reopen(_ key: String) { decide(key, .pending) }

    var canSaveReview: Bool { isReviewComplete && !isSaving }

    /// Puts the kept answers into the visit form and goes back to it; the draft saves them. `aiAssisted` is set
    /// here and only here, from a finished review. Nothing is finalized: she reads the form and finalizes it herself.
    func saveReview() async {
        guard canSaveReview else { return }
        let merged = ReviewMerge.apply(proposals, to: draft)
        showsValidation = true
        guard !merged.isEmpty else { return }
        draft = merged
        aiAssisted = aiAssisted || ReviewMerge.isAIAssisted(proposals)
        proposals = []
        returnToForm()
        draftChanged()
        await autosaveNow()
    }

    func saveReviewTapped() { Task { await saveReview() } }

    /// Nothing is kept: she dropped every card and chose no result.
    var reviewIsEmptyAfterDecisions: Bool {
        isReviewComplete && ReviewMerge.apply(proposals, to: draft).isEmpty
    }

    // MARK: - Private

    private func decide(_ key: String, _ decision: ReviewProposal.Decision) {
        guard let index = proposals.firstIndex(where: { $0.field.key == key }) else { return }
        proposals[index].decision = decision
    }
}
