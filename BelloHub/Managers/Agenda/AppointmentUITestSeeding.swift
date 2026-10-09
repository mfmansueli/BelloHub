//
//  AppointmentUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// The calendar a UI test of the visit screens starts from (`-uiSeed appointments`): Ana with a visit in two days and
/// Beatriz with a visit that started hours ago (`AppointmentFixtures`). The workspace itself is the `onboarded` seed;
/// this only adds the visits. DEBUG only.
enum AppointmentUITestSeeding {
    @MainActor
    static func seedIfRequested(_ dependencies: AppDependencies, options: LaunchOptions) async {
        guard options.seed == "appointments", !options.keepsState,
              let repository = dependencies.vault.repository else { return }
        _ = try? await AppointmentFixtures.seed(into: repository, now: Date())
    }
}
#endif
