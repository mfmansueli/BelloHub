//
//  FormTemplateError.swift
//  BelloHub
//

/// What `FormTemplateRepository` refuses.
enum FormTemplateError: Error, Equatable {
    /// The version exists with other questions. Edit by saving the next version instead.
    case versionLocked
}
