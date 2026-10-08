//
//  OnboardingStep.swift
//  BelloHub
//

/// The steps of the workspace setup, in order. One ViewModel drives all of them (docs/04-ARCHITECTURE.md section 5),
/// so going back and forward keeps every choice.
enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case about
    case profession
    case services
    case terminology
    case tags
    case record
    case permissions
    case ready

    var id: Int { rawValue }

    /// Steps that show the progress bar: the ones where she chooses how the app works.
    static let counted: [OnboardingStep] = [.about, .profession, .services, .terminology, .tags, .record]

    /// 1-based position in the progress bar, or nil on the steps outside it.
    var progressPosition: Int? {
        Self.counted.firstIndex(of: self).map { $0 + 1 }
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Stable fragment for accessibility identifiers (`onboarding.<name>.…`).
    var name: String {
        switch self {
        case .about: "about"
        case .profession: "profession"
        case .services: "services"
        case .terminology: "terminology"
        case .tags: "tags"
        case .record: "record"
        case .permissions: "permissions"
        case .ready: "ready"
        }
    }
}
