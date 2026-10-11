//
//  ContraindicationStatus.swift
//  BelloHub
//

import Foundation

/// The result of checking the visit's service against the client's health form, in the words the screen needs
/// (D16: it warns and never blocks).
enum ContraindicationStatus: Equatable, Sendable {
    /// The service lists no contraindication, so there is nothing to check.
    case noneListed
    /// The service lists some and the client has no health form yet, so "no warning" would mean "unknown".
    case noHealthForm
    /// Checked, nothing triggers. `unchecked` are the ones the answers cannot decide (she wrote them herself).
    case clear(unchecked: [String])
    /// Checked, and these answers trigger a contraindication.
    case warnings([ContraindicationLine], unchecked: [String])

    static func make(service: Service?, form: HealthForm?, catalog: HealthFormCatalog?) -> ContraindicationStatus {
        guard let service, !service.contraindications.isEmpty else { return .noneListed }
        guard let catalog else { return .noHealthForm }
        let report = ContraindicationMatcher.check(
            contraindications: service.contraindications, form: form, catalog: catalog
        )
        guard report.hasHealthForm else { return .noHealthForm }
        let lines = report.matches.map { line(for: $0, catalog: catalog) }
        return lines.isEmpty ? .clear(unchecked: report.unchecked) : .warnings(lines, unchecked: report.unchecked)
    }

    var hasWarnings: Bool {
        if case .warnings = self { return true }
        return false
    }

    private static func line(
        for match: ContraindicationReport.Match, catalog: HealthFormCatalog
    ) -> ContraindicationLine {
        guard let key = match.questionKey, let question = catalog.question(for: key) else { return .minor }
        return .answer(question: question.name, option: match.optionKey.flatMap(question.optionName(for:)))
    }
}
