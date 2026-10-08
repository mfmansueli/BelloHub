//
//  DesignCatalogView.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Every token and component in one scroll, with switches for locale (including right-to-left Arabic and
/// Devanagari Hindi), Dynamic Type up to AX5 and appearance. Reached with `-designCatalog`. Text here is a
/// developer tool, so section labels are verbatim; the sample content inside the components is localized
/// (`catalog.sample.*`) so the long and non-Latin cases render for real.
struct DesignCatalogView: View {
    @State private var localeID: String
    @State private var appearance: CatalogAppearance = .system
    @State private var textSize: CatalogTextSize = .standard

    private let initialSection: String?

    init(options: LaunchOptions = LaunchOptions()) {
        _localeID = State(initialValue: options.uiLocaleID ?? AppLocalization.en.rawValue)
        _appearance = State(initialValue: options.catalogDark ? .dark : .system)
        _textSize = State(initialValue: CatalogTextSize(rawValue: options.catalogTextSize ?? "") ?? .standard)
        initialSection = options.catalogSection
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    StaggeredStack {
                        CatalogColorsSection().id("colors")
                        CatalogTypographySection().id("typography")
                        CatalogButtonsSection().id("buttons")
                        CatalogComponentsSection().id("components")
                        CatalogMotionSection().id("motion")
                    }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.bottom, Spacing.xl)
                }
                .task {
                    if let initialSection { proxy.scrollTo(initialSection, anchor: .top) }
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text(verbatim: "Design catalog"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { controls } }
        }
        .accessibilityIdentifier("catalog.root")
        .environment(\.locale, locale)
        .environment(\.layoutDirection, layoutDirection)
        .belloLocaleTypography()
        .dynamicTypeSize(textSize.dynamicTypeSize)
        .preferredColorScheme(appearance.colorScheme)
    }

    private var locale: Locale {
        Locale(identifier: localeID)
    }

    private var layoutDirection: LayoutDirection {
        AppLocalization(rawValue: localeID)?.isRightToLeft == true ? .rightToLeft : .leftToRight
    }

    private var controls: some View {
        Menu {
            Picker(selection: $localeID) {
                ForEach(AppLocalization.allCases) { localization in
                    Text(verbatim: localization.nativeName).tag(localization.rawValue)
                }
            } label: { Text(verbatim: "Language") }
            Picker(selection: $textSize) {
                ForEach(CatalogTextSize.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Text size") }
            Picker(selection: $appearance) {
                ForEach(CatalogAppearance.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            } label: { Text(verbatim: "Appearance") }
        } label: {
            Image(icon: .sliders)
        }
        .accessibilityLabel(Text(verbatim: "Catalog options"))
        .accessibilityIdentifier("catalog.options")
    }
}

#Preview {
    DesignCatalogView()
}
#endif
