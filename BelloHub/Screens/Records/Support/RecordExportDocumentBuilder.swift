//
//  RecordExportDocumentBuilder.swift
//  BelloHub
//

import Foundation

/// Lays `RecordExportContent` out as a `RecordExportDocument`: which words and in which order. It adds nothing the
/// selector left out. Words come from `resolve` (her language), dates from `formatters`.
struct RecordExportDocumentBuilder {
    let resolve: (LocalizedStringResource) -> String
    let formatters: Formatters
    let professionalName: String
    let now: Date

    typealias Section = RecordExportDocument.Section

    /// `photoData` holds the processed image of each included photo; a photo with no data is left out of the PDF.
    func document(for content: RecordExportContent, photoData: [UUID: Data]) -> RecordExportDocument {
        let name = content.clientName
        let date = formatters.shortDate(now)
        var sections: [Section] = []
        if let health = content.health { sections.append(healthSection(health)) }
        if !content.consents.isEmpty { sections.append(consentSection(content.consents)) }
        sections += content.treatments.map(treatmentSection)
        if !content.incidents.isEmpty { sections.append(incidentSection(content.incidents)) }
        let pictures = content.photos.compactMap { photo in photoData[photo.id].map { (photo, $0) } }
        if !pictures.isEmpty { sections.append(photoSection(pictures)) }
        return RecordExportDocument(
            title: resolve(LocalizedStringResource("exportRecord.doc.title", defaultValue: "\(name) · Client record")),
            subtitle: resolve(LocalizedStringResource(
                "exportRecord.doc.subtitle", defaultValue: "\(professionalName) · exported \(date)"
            )),
            fileName: ExportFileName.make(clientName: name, suffix: resolve("exportRecord.doc.fileSuffix")),
            sections: sections,
            footer: resolve("exportRecord.footer")
        )
    }

    // MARK: - Sections

    private func healthSection(_ health: RecordExportContent.Health) -> Section {
        var items: [RecordExportDocument.Item] = []
        if !health.allergies.isEmpty {
            items.append(.line(label: resolve("exportRecord.doc.allergies"), value: formatters.list(health.allergies)))
        }
        if !health.sensitivities.isEmpty {
            items.append(.line(
                label: resolve("exportRecord.doc.sensitivities"), value: formatters.list(health.sensitivities)
            ))
        }
        if let note = health.importantNote {
            items.append(.line(label: resolve("exportRecord.doc.importantNote"), value: note))
        }
        return Section(heading: resolve("exportRecord.doc.health"), items: items)
    }

    /// Each consent record as her label (or the kind's title) with "Signed <date>" or "Not signed" (D55).
    private func consentSection(_ consents: [ConsentRecord]) -> Section {
        let items = consents.map { consent -> RecordExportDocument.Item in
            let value: String
            if consent.isSigned {
                let signed = formatters.shortDate(consent.effectiveDate)
                value = resolve(LocalizedStringResource("exportRecord.doc.signed", defaultValue: "Signed \(signed)"))
            } else {
                value = resolve("exportRecord.doc.notSigned")
            }
            return .line(
                label: consent.displayLabel(kindTitle: resolve(consent.kind.title)), value: value
            )
        }
        return Section(heading: resolve("exportRecord.doc.consent"), items: items)
    }

    private func treatmentSection(_ treatment: RecordExportContent.Treatment) -> Section {
        let record = treatment.record
        let service = record.serviceName
        let date = formatters.shortDate(record.createdAt)
        var items: [RecordExportDocument.Item] = [
            .line(label: resolve("exportRecord.doc.result"), value: resolve(record.result.title))
        ]
        if !record.productsUsed.isEmpty {
            items.append(.line(
                label: resolve("exportRecord.doc.products"), value: formatters.list(record.productsUsed)
            ))
        }
        for field in RecordCorrectableField.allCases {
            // What the record says now, so a corrected value shows as corrected and the log below says why.
            let current = RecordEditRules.currentValue(of: field, in: record, corrections: treatment.corrections)
            if let current, !current.isEmpty { items.append(.line(label: resolve(field.title), value: current)) }
        }
        for entry in record.fieldEntries ?? [] {
            items.append(.line(label: entry.name, value: entry.value.replacingOccurrences(of: "\n", with: ", ")))
        }
        items += treatment.corrections.map(correctionItem)
        return Section(
            heading: resolve(LocalizedStringResource("exportRecord.doc.visit", defaultValue: "\(service) · \(date)")),
            items: items
        )
    }

    private func correctionItem(_ correction: RecordCorrection) -> RecordExportDocument.Item {
        let date = formatters.dateTime(correction.createdAt)
        let known = RecordCorrectableField(rawValue: correction.fieldKey)
        let field = known.map { resolve($0.title) } ?? correction.fieldKey
        let reason = correction.reason ?? ""
        let text = resolve(LocalizedStringResource(
            "exportRecord.doc.correction", defaultValue: "Correction, \(date), \(field): \(reason)"
        ))
        return .text(text)
    }

    private func incidentSection(_ incidents: [Incident]) -> Section {
        let items = incidents.map { incident -> RecordExportDocument.Item in
            let date = formatters.shortDate(incident.occurredAt)
            let severity = resolve(incident.severity.title)
            let parts = [incident.symptoms, incident.area, incident.actionTaken].compactMap { $0 }
            return .line(
                label: resolve(LocalizedStringResource(
                    "exportRecord.doc.incident", defaultValue: "\(date) · \(severity)"
                )),
                value: parts.joined(separator: " · ")
            )
        }
        return Section(heading: resolve("exportRecord.doc.incidents"), items: items)
    }

    private func photoSection(_ pictures: [(Photo, Data)]) -> Section {
        let items = pictures.map { photo, data -> RecordExportDocument.Item in
            let kind = resolve(photo.kind.title)
            let date = formatters.shortDate(photo.takenAt)
            return .photo(image: data, caption: "\(kind) · \(date)")
        }
        return Section(heading: resolve("exportRecord.doc.photos"), items: items)
    }
}
