//
//  ClientDocumentsSection.swift
//  BelloHub
//

import SwiftUI

/// "Documents": what is on paper or was sent, kept apart by who it belongs to.
///
/// - Her own documentation (consent notes and the photo or file of a signed paper): private to her.
/// - What the client sent (the health form from the booking page): read here, never required to open the record.
/// - Sharing with the client: which photos she can see. A signed photo consent is the only thing that allows it, and
///   it allows only that; no signature opens the rest of the record to anyone.
/// - Portfolio use: the photos marked one by one for her portfolio, under the same consent, kept apart from sharing.
struct ClientDocumentsSection: View {
    let snapshot: ClientProfileSnapshot
    let timeline: ClientTimeline
    let formatters: Formatters
    let onOpenHealth: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("clientRecord.documents.own")
            own
            sectionTitle("clientRecord.documents.fromClient")
            fromClient
            sectionTitle("clientRecord.documents.sharing")
            sharing
            sectionTitle("clientRecord.documents.portfolio")
            portfolio
            Button(action: onOpenHealth) {
                Label { Text("clientRecord.documents.manage") } icon: { Image(icon: .document) }
            }
            .buttonStyle(.belloSecondary)
            .padding(.top, Spacing.lg)
            .accessibilityIdentifier("clientRecord.documents.manage")
        }
        .accessibilityIdentifier("clientRecord.documents")
    }

    // MARK: - Sections

    @ViewBuilder
    private var own: some View {
        if snapshot.consents.isEmpty {
            emptyLine("clientRecord.documents.own.empty")
        } else {
            ListCard(dividerInset: Spacing.md) {
                ForEach(snapshot.consents) { consent in
                    ConsentRecordRow(record: consent, formatters: formatters,
                                     identifier: "clientRecord.documents.consent.\(consent.id.uuidString)",
                                     action: onOpenHealth)
                }
            }
        }
        FooterNote(text: "clientRecord.documents.own.private", icon: .lock)
            .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private var fromClient: some View {
        let forms = snapshot.forms
        if forms.isEmpty {
            emptyLine("clientRecord.documents.fromClient.empty")
        } else {
            ListCard(dividerInset: Spacing.md) {
                ForEach(forms) { form in formRow(form) }
            }
        }
        FooterNote(text: "clientRecord.documents.fromClient.note", icon: .info)
            .padding(.top, Spacing.sm)
    }

    private var photos: [Photo] { timeline.visits.flatMap(\.photos) + timeline.unlinkedPhotos }

    private var hasPhotoConsent: Bool { PhotoConsentRules.latestPhotoConsent(snapshot.consents) != nil }

    private var sharing: some View {
        let shared = photos.filter { $0.visibility == .shareWithClient }.count
        let privateCount = photos.filter { $0.visibility == .professionalOnly }.count
        return infoCard(identifier: "clientRecord.documents.sharingCard") {
            Text(LocalizedStringResource(
                "clientRecord.documents.sharing.withClient", defaultValue: "Photos the client can see: \(shared)"
            ).localized(in: locale))
            .font(Typography.body).foregroundStyle(Palette.ink)
            Text(LocalizedStringResource(
                "clientRecord.documents.sharing.privateCount", defaultValue: "Private photos: \(privateCount)"
            ).localized(in: locale))
            .font(Typography.body).foregroundStyle(Palette.ink)
            Text(hasPhotoConsent
                 ? "clientRecord.documents.sharing.consented" : "clientRecord.documents.sharing.private")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    private var portfolio: some View {
        let marked = photos.filter { $0.visibility == .portfolio }.count
        return infoCard(identifier: "clientRecord.documents.portfolioCard") {
            Text(LocalizedStringResource(
                "clientRecord.documents.portfolio.count", defaultValue: "Photos marked for portfolio: \(marked)"
            ).localized(in: locale))
            .font(Typography.body).foregroundStyle(Palette.ink)
            Text("clientRecord.documents.portfolio.note").font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    private func infoCard(identifier: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) { content() }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard(cornerRadius: Radius.tile)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }

    // MARK: - Pieces

    private func formRow(_ form: HealthForm) -> some View {
        HStack(spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("clientRecord.documents.healthForm")
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: formDetail(form))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: Spacing.sm)
            if form.signedAt != nil {
                StatusChip(label: "health.consent.status.signed", style: StatusPalette.confirmed)
            } else {
                StatusChip(label: "health.consent.status.notSigned", style: StatusPalette.pending)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("clientRecord.documents.form.\(form.id.uuidString)")
    }

    private func formDetail(_ form: HealthForm) -> String {
        let who = form.filledBy == .client
            ? LocalizedStringResource("clientRecord.documents.healthForm.byClient").resolved(in: locale)
            : LocalizedStringResource("clientRecord.documents.healthForm.byYou").resolved(in: locale)
        guard let signedAt = form.signedAt else { return who }
        return "\(formatters.shortDate(signedAt)) · \(who)"
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Typography.section)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Spacing.section)
            .padding(.bottom, Spacing.row)
    }

    private func emptyLine(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.meta)
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
