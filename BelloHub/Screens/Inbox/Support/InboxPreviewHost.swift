//
//  InboxPreviewHost.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Puts the inbox screens' Services in the environment for previews: an in-memory vault and the UI-test inbox server
/// with its fixtures (a booking request, a reschedule request, a cancelled time and three people waiting). DEBUG only.
struct InboxPreviewHost<Content: View>: View {
    @State private var vault: VaultService
    @State private var sync: BookingSyncService
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        let vault = VaultService(repository: InMemoryClientRecordRepository())
        let defaults = UserDefaults(suiteName: "app.bellohub.previews.inbox") ?? .standard
        let repository = UITestInboxRepository(
            scenario: .fixtures, publicKey: { throw BookingRepositoryError.rejected }
        )
        let queue = OutboundQueue(repository: repository, defaults: defaults)
        _vault = State(initialValue: vault)
        _sync = State(initialValue: BookingSyncService(
            repository: repository, queue: queue, appointments: AppointmentService(vault: vault), vault: vault,
            defaults: defaults, pollInterval: nil
        ))
        self.content = content
    }

    var body: some View {
        content()
            .environment(vault)
            .environment(sync)
            .environment(ProfileService(vault: vault))
            .environment(SubscriptionService.preview())
            .task { sync.startListening(userId: "preview") }
    }
}
#endif
