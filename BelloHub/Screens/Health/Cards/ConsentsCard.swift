//
//  ConsentsCard.swift
//  BelloHub
//

import SwiftUI

/// One folder of papers signed in person: her health forms (D60) or her consents (D55), the most recent first, and
/// the action that adds one. The header shows how many there are. Each row opens the record for editing.
struct ConsentsCard: View {
    /// Which folder: the words and identifiers differ, the rows and the sheet are the same.
    enum Folder {
        case healthForms
        case consents

        fileprivate var title: LocalizedStringKey {
            self == .healthForms ? "health.section.forms" : "health.section.consent"
        }

        fileprivate var empty: LocalizedStringKey {
            self == .healthForms ? "health.forms.empty" : "health.consent.empty"
        }

        fileprivate var add: LocalizedStringKey {
            self == .healthForms ? "health.forms.add" : "health.consent.add"
        }

        fileprivate var footnote: LocalizedStringKey {
            self == .healthForms ? "health.forms.footnote" : "health.consent.footnote"
        }

        /// "health.forms" or "health.consent", the prefix of the identifiers.
        fileprivate var prefix: String {
            self == .healthForms ? "health.forms" : "health.consent"
        }

        fileprivate var addIdentifier: String {
            self == .healthForms ? "health.addFormButton" : "health.addConsentButton"
        }
    }

    var folder = Folder.consents
    let consents: [ConsentRecord]
    let formatters: Formatters
    let onOpen: (ConsentRecord) -> Void
    let onAdd: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ListCard(dividerInset: Spacing.md) {
                if consents.isEmpty {
                    Text(folder.empty)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("\(folder.prefix).empty")
                } else {
                    ForEach(consents) { consent in
                        ConsentRecordRow(
                            record: consent, formatters: formatters,
                            identifier: "\(folder.prefix).\(consent.id.uuidString)"
                        ) {
                            onOpen(consent)
                        }
                    }
                }
                addButton
            }
            Text(folder.footnote)
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.top, Spacing.sm)
                .accessibilityIdentifier("\(folder.prefix).footnote")
        }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(folder.title)
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            if !consents.isEmpty {
                Text(LocalizedStringResource(
                    "health.consent.count", defaultValue: "\(consents.count) records"
                ).localized(in: locale))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            HStack(spacing: Spacing.sm) {
                Image(icon: .plus).font(.system(size: 15, weight: .semibold)).accessibilityHidden(true)
                Text(folder.add).font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(folder.addIdentifier)
    }
}
