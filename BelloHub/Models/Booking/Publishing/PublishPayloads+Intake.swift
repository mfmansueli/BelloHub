//
//  PublishPayloads+Intake.swift
//  BelloHub
//

extension PublishPayloads {
    /// The questions she asks, in her order, each with the catalog sentence of every booking language. A question
    /// no catalog knows (a key from a newer build) is left out rather than published without words; nil when nothing
    /// is left, so the page says there is no form instead of showing an empty one.
    static func intake(
        _ form: HealthFormPublication, locales: [AppLocalization]
    ) -> PublishProfileRequest.Intake? {
        let questions = form.template.questionKeys.compactMap { question($0, form: form, locales: locales) }
        guard !questions.isEmpty else { return nil }
        return .init(formVersion: min(max(form.template.version, 1), 1000), template: .init(questions: questions))
    }

    /// One question in the page's vocabulary: `choices` is a `multiChoice` whose "None" (when the catalog offers it)
    /// is the last option, under the key the app stores.
    private static func question(
        _ key: String, form: HealthFormPublication, locales: [AppLocalization]
    ) -> PublishProfileRequest.Question? {
        var labels: [String: String] = [:]
        var kind: HealthQuestionKind?
        var optionKeys: [String] = []
        var optionLabels: [String: [String: String]] = [:]
        for locale in locales {
            guard let question = form.catalogs[locale]?.question(for: key) else { continue }
            labels[locale.rawValue] = question.prompt
            kind = kind ?? question.kind
            var keys = question.options.map(\.key)
            for option in question.options {
                optionLabels[option.key, default: [:]][locale.rawValue] = option.name
            }
            if question.allowsNone, let none = form.noneLabels[locale] {
                keys.append(HealthOption.noneKey)
                optionLabels[HealthOption.noneKey, default: [:]][locale.rawValue] = none
            }
            optionKeys += keys.filter { !optionKeys.contains($0) }
        }
        guard let kind, !labels.isEmpty else { return nil }
        switch kind {
        case .yesNo:
            return .init(key: key, kind: "yesNo", label: labels, options: nil)
        case .text:
            return .init(key: key, kind: "text", label: labels, options: nil)
        case .choices:
            let options = optionKeys.map { PublishProfileRequest.Option(value: $0, label: optionLabels[$0] ?? [:]) }
            return options.isEmpty ? nil : .init(key: key, kind: "multiChoice", label: labels, options: options)
        }
    }
}
