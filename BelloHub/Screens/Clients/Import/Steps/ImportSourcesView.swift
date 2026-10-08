//
//  ImportSourcesView.swift
//  BelloHub
//

import SwiftUI

/// 4.6 ImportClients, first step: where the clients come from. Phone contacts (the system picker), a spreadsheet
/// (CSV), and other booking apps (coming soon). The free-registration note sits under the choices, before anything is
/// imported (D42).
struct ImportSourcesView: View {
    let viewModel: ImportClientsViewModel
    let term: ClientTerm
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                header
                if let problem = viewModel.problem { problemNotice(problem) }
                sources
                notes
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(LocalizedStringResource(
                "import.sources.title", defaultValue: "Bring your \(term.pluralText(in: locale)) with you."
            ).localized(in: locale))
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importClients.sources.title")
            Text("import.sources.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
        }
    }

    private var sources: some View {
        ListCard {
            ImportSourceRow(
                icon: .user, tone: .sand, title: "import.source.contacts.title",
                subtitle: "import.source.contacts.subtitle", identifier: "importClients.source.contacts",
                action: viewModel.chooseContacts
            )
            ImportSourceRow(
                icon: .document, tone: .sage, title: "import.source.spreadsheet.title",
                subtitle: "import.source.spreadsheet.subtitle", identifier: "importClients.source.spreadsheet",
                action: viewModel.chooseSpreadsheet
            )
            ImportSourceRow(
                icon: .download, tone: .neutral, title: "import.source.others.title",
                subtitle: "import.source.others.subtitle", identifier: "importClients.source.others"
            )
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            RegistrationLimitNote(usage: viewModel.usage)
            FooterNote(text: "import.sources.spreadsheetHint", icon: .document)
            FooterNote(text: "import.sources.privacy", icon: .lock)
        }
    }

    // MARK: - Problems

    /// A restricted contacts list explains itself and offers Settings; every other problem is one line.
    @ViewBuilder
    private func problemNotice(_ problem: ImportProblem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            InlineNotice(style: .warning, title: problem.title, message: problem.message)
                .accessibilityIdentifier("importClients.problem")
            if problem == .contactsRestricted {
                Button { viewModel.openSettings() } label: { Text("import.openSettings") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("importClients.openSettingsButton")
            }
        }
    }
}
