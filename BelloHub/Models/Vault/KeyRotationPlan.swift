//
//  KeyRotationPlan.swift
//  BelloHub
//

/// The inbox key generations (docs/06-PRIVACY-SECURITY.md section 4.3, "she rotates the inbox key"): v1 ships the
/// model and its tests, no screen. Every generation is derived from the same seed (`KeyDerivation.inboxSeed`), so a
/// rotation needs no new secret: the new generation becomes the one the booking page publishes, and the old ones
/// stay derivable to open envelopes already sealed for them. Nothing is ever below generation 1.
struct KeyRotationPlan: Equatable, Codable, Sendable {
    static let firstGeneration = 1

    /// The generation the public key id of the booking page points at.
    private(set) var currentGeneration: Int
    /// Generations that still have envelopes pending in the mailbox (or may have), oldest first. The current one is
    /// never listed here.
    private(set) var retiredGenerations: [Int]

    init(currentGeneration: Int = KeyRotationPlan.firstGeneration, retiredGenerations: [Int] = []) {
        self.currentGeneration = max(currentGeneration, Self.firstGeneration)
        self.retiredGenerations = retiredGenerations.filter { $0 >= Self.firstGeneration && $0 < currentGeneration }
            .sorted()
    }

    /// Every generation whose private key must still be derivable: the retired ones and the current one.
    var openableGenerations: [Int] {
        retiredGenerations + [currentGeneration]
    }

    /// Moves to the next generation. The one that was current joins the retired list, because the page may have
    /// sealed envelopes for it minutes ago.
    func rotated() -> KeyRotationPlan {
        KeyRotationPlan(
            currentGeneration: currentGeneration + 1, retiredGenerations: retiredGenerations + [currentGeneration]
        )
    }

    /// Forgets a retired generation once the mailbox has no envelope left for it. The current one cannot be retired.
    func retiring(_ generation: Int) -> KeyRotationPlan {
        KeyRotationPlan(
            currentGeneration: currentGeneration, retiredGenerations: retiredGenerations.filter { $0 != generation }
        )
    }

    func canOpen(generation: Int) -> Bool {
        openableGenerations.contains(generation)
    }
}
