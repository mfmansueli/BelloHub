//
//  HealthQuestionKind.swift
//  BelloHub
//

/// How a health question is answered. The raw value is the one in the catalog files, so **never rename one**. It maps
/// onto the answer values `HealthAnswer` already stores: `yesNo` is `.yes` or `.no`, `choices` is `.choices([key])`
/// and `text` is `.text`.
enum HealthQuestionKind: String, Hashable, Sendable {
    case yesNo
    case choices
    case text
}
