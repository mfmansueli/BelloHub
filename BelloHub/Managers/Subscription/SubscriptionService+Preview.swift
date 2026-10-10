//
//  SubscriptionService+Preview.swift
//  BelloHub
//

#if DEBUG
extension SubscriptionService {
    /// A service with a scripted store and no server, for UI-test launches (`-uiPlan`) and `#Preview` blocks: it never
    /// opens a payment sheet and never calls the server.
    static func preview(hasPlan: Bool = false) -> SubscriptionService {
        SubscriptionService(
            provider: UITestSubscriptionProvider(hasPlan: hasPlan), verifier: OfflineSubscriptionVerifier()
        )
    }
}
#endif
