//
//  OnboardingStep.swift
//  BelloHub
//

/// The steps of the workspace setup, in order. One ViewModel drives all of them (docs/04-ARCHITECTURE.md section 5),
/// so going back and forward keeps every choice. Routine-a item 3: name, profession and a first service, then Ready.
/// Tags, the words the app uses and the record fields take the profession's defaults and are changed later in More;
/// system permissions are asked when the feature that needs them is used.
enum OnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case about
    case profession
    case services
    case ready

    var id: Int { rawValue }

    /// Steps that show the progress bar: the ones where she chooses how the app works.
    static let counted: [OnboardingStep] = [.about, .profession, .services]

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

    /// Stable fragment for accessibility identifiers (`onboarding.<name>.…`) and for the saved progress.
    var name: String {
        switch self {
        case .about: "about"
        case .profession: "profession"
        case .services: "services"
        case .ready: "ready"
        }
    }

    init?(name: String) {
        guard let step = Self.allCases.first(where: { $0.name == name }) else { return nil }
        self = step
    }
}
