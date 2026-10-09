//
//  ImportMappingView.swift
//  BelloHub
//

import SwiftUI

/// Second step of a spreadsheet import: which column is the name, the phone and the e-mail. The first guess comes from
/// the titles (in the product's languages) and, failing that, from the values; every choice is a native menu, and the
/// first rows are previewed with the choices applied.
struct ImportMappingView: View {
    let viewModel: ImportClientsViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            StaggeredStack(spacing: Spacing.lg) {
                header
                headerToggle
                columns
                if viewModel.mapping.hasName { preview } else { needsName }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("import.mapping.title")
                .font(Typography.title)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importClients.mapping.title")
            Text(verbatim: fileSummary).font(Typography.metaStrong).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("importClients.mapping.file")
            Text("import.mapping.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
        }
    }

    /// "clients.csv · 238 rows" in one line, so VoiceOver reads the file and its size together instead of a bare
    /// file name.
    private var fileSummary: String {
        let rows = String(localized: LocalizedStringResource(
            "import.mapping.rows", defaultValue: "\(viewModel.table?.rows.count ?? 0) rows"
        ).localized(in: locale))
        guard let fileName = viewModel.fileName else { return rows }
        return "\(BidiIsolate.wrap(fileName)) · \(rows)"
    }

    private var headerToggle: some View {
        ToggleRow(
            title: String(localized: LocalizedStringResource("import.mapping.headerRow").localized(in: locale)),
            isOn: Binding(
                get: { viewModel.table?.hasHeader ?? false },
                set: { viewModel.setFirstRowIsHeader($0) }
            ),
            identifier: "importClients.mapping.headerToggle"
        )
        .belloCard()
    }

    private var columns: some View {
        let options = viewModel.table.map(ImportColumnOption.options(for:)) ?? []
        return ListCard(dividerInset: Spacing.md) {
            ForEach(ImportColumnRole.allCases, id: \.self) { role in
                ImportColumnPickerRow(
                    role: role, options: options,
                    selection: Binding(get: { viewModel.mapping[role] }, set: { viewModel.setColumn(role, to: $0) })
                )
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("import.mapping.preview").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.mappingPreview) { entry in
                    ImportPreviewRow(entry: entry, phoneText: viewModel.phoneText(for: entry))
                }
            }
        }
    }

    private var needsName: some View {
        InlineNotice(style: .info, title: "import.mapping.needName")
            .accessibilityIdentifier("importClients.mapping.needName")
    }

    private var actionBar: some View {
        Button { viewModel.confirmMappingAndContinue() } label: { Text("import.continue") }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canContinueFromMapping)
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
            .background(Palette.bg)
            .accessibilityIdentifier("importClients.mapping.continueButton")
            .motionBar()
    }
}
