//
//  AppLanguageSection.swift
//  BelloHub
//

import SwiftUI

/// The first section of Language and region: the language of the app itself (routine-a item 1), apart from the
/// language of her messages and page. Applied at once, without Save: it is a setting of this iPhone, not of the
/// business, and every open screen follows it.
struct AppLanguageSection: View {
    @Environment(InterfaceLanguageService.self) private var interfaceLanguage

    var body: some View {
        SettingsSection(
            title: "languageRegion.section.appLanguage", subtitle: "languageRegion.section.appLanguage.subtitle"
        ) {
            ListCard(dividerInset: Spacing.md) {
                HStack(spacing: Spacing.row) {
                    Text("languageRegion.language").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(selection: selection) {
                        Text("languageRegion.appLanguage.system").tag(InterfaceLanguage.system)
                        ForEach(AppLocalization.allCases) { localization in
                            Text(verbatim: localization.nativeName).tag(InterfaceLanguage.fixed(localization))
                        }
                    } label: {
                        Text("languageRegion.language")
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.roseText)
                    .accessibilityIdentifier("languageRegion.appLanguageMenu")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            FooterNote(text: "languageRegion.appLanguage.system.note", icon: .info)
                .padding(.top, Spacing.xs)
        }
    }

    private var selection: Binding<InterfaceLanguage> {
        Binding(get: { interfaceLanguage.choice }, set: { interfaceLanguage.choose($0) })
    }
}

#Preview {
    ScrollView { AppLanguageSection().padding() }
        .environment(InterfaceLanguageService(defaults: .standard, systemDefaults: nil))
}
