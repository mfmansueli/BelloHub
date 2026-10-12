//
//  SubscriptionService+Preview.swift
//  BelloHub
//

#if DEBUG
extension SubscriptionService {
    /// A service with a scripted store and a snapshot that does not outlive the process, for UI-test launches
    /// (`-uiPlan`) and `#Preview` blocks: it never opens a payment sheet.
    static func preview(hasPlan: Bool = false) -> SubscriptionService {
        SubscriptionService(
            provider: UITestSubscriptionProvider(hasPlan: hasPlan),
            verifier: DeviceSubscriptionVerifier(store: EphemeralSubscriptionSnapshotStore())
        )
    }
}
#endif
