//
//  OnboardingBuilder.swift
//  BelloHub
//

import Foundation

/// Turns the draft into the values the vault stores. Pure: the clock and the id source are parameters, so the same
/// draft always gives the same result in a test.
enum OnboardingBuilder {
    /// Color tokens custom tags rotate through, so a row of new tags is not all one color.
    static let customTagColors = ["rose", "sage", "peach", "sand"]

    static func build(
        draft: OnboardingDraft, catalog: ProfessionCatalog, now: Date, makeID: () -> UUID = UUID.init
    ) -> OnboardingResult {
        let profile = ProfessionalProfile(
            displayName: OnboardingRules.cleaned(draft.displayName),
            businessName: OnboardingRules.cleaned(draft.businessName),
            regionCode: draft.regionCode,
            timeZoneID: draft.timeZoneID,
            currencyCode: draft.currencyCode,
            appLocaleID: draft.localization.rawValue,
            bookingLocaleIDs: draft.bookingLocaleIDs,
            professions: draft.professions,
            clientTerm: draft.clientTerm,
            vocabulary: draft.vocabulary,
            createdAt: now
        )
        return OnboardingResult(
            profile: profile,
            services: services(draft: draft, catalog: catalog, makeID: makeID),
            tags: tags(draft: draft, catalog: catalog, makeID: makeID),
            template: template(draft: draft, catalog: catalog, now: now)
        )
    }

    // MARK: - Parts

    private static func services(draft: OnboardingDraft, catalog: ProfessionCatalog, makeID: () -> UUID) -> [Service] {
        // Her first service comes first; durations and prices she set replace the catalog's.
        let chosen = OnboardingSuggestions.services(for: draft.professions, in: catalog)
            .filter { draft.selectedServiceKeys.contains($0.key) }
        let ordered = chosen.filter { $0.key == draft.firstServiceKey } + chosen.filter { $0.key != draft.firstServiceKey }
        let suggested = ordered
            .map { item in
                Service(id: makeID(), name: item.name, category: item.category,
                        durationMinutes: draft.serviceMinutes[item.key] ?? item.minutes,
                        priceAmount: draft.servicePrices[item.key], followUpWeeks: item.followUpWeeks,
                        remindBeforeAfterPhotos: item.photos)
            }
        let custom = draft.customServices.map { item in
            Service(
                id: item.id, name: OnboardingRules.cleaned(item.name), category: OnboardingRules.cleaned(item.category),
                durationMinutes: item.minutes, priceAmount: item.priceAmount, followUpWeeks: item.followUpWeeks,
                remindBeforeAfterPhotos: item.remindsPhotos,
                // An empty text means "send aftercare, the words come later" (docs/05-DATA-MODEL.md, Service).
                aftercareTemplate: item.sharesAftercare ? "" : nil
            )
        }
        return (suggested + custom).enumerated().map { index, service in
            var positioned = service
            positioned.position = index
            return positioned
        }
    }

    private static func tags(draft: OnboardingDraft, catalog: ProfessionCatalog, makeID: () -> UUID) -> [Tag] {
        let suggested = OnboardingSuggestions.tags(for: draft.professions, in: catalog)
            .filter { draft.selectedTagKeys.contains($0.key) }
            .map { (name: $0.name, color: $0.color) }
        let custom = draft.customTags.enumerated().map { index, name in
            (name: name, color: customTagColors[index % customTagColors.count])
        }
        return (suggested + custom).enumerated().map { index, tag in
            Tag(id: makeID(), name: tag.name, colorToken: tag.color, position: index)
        }
    }

    private static func template(draft: OnboardingDraft, catalog: ProfessionCatalog, now: Date) -> RecordTemplate {
        var fields: [RecordFieldSetting] = []
        var intake: [IntakeSetting] = []
        for profession in draft.professions {
            guard let entry = catalog.entry(for: profession) else { continue }
            for field in entry.fields {
                var setting = RecordFieldSetting(profession: profession, key: field.key, isOn: field.on)
                setting.isOn = draft.fieldOverrides[setting.id] ?? field.on
                fields.append(setting)
            }
            for item in IntakeItem.allCases {
                var setting = IntakeSetting(profession: profession, item: item, isOn: entry.intake.contains(item))
                setting.isOn = draft.intakeOverrides[setting.id] ?? setting.isOn
                intake.append(setting)
            }
        }
        return RecordTemplate(fields: fields, intake: intake, updatedAt: now)
    }
}
