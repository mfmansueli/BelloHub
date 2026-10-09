//
//  ClientMessageView.swift
//  BelloHub
//

import SwiftUI

/// The sheet that opens a follow-up, win-back or birthday message (opened with `AgendaSheet.clientMessage`). It reads
/// the Services from the environment and hands them to `ClientMessageContentView`, which owns the ViewModel.
struct ClientMessageView: View {
    let request: ClientMessageRequest
    @Environment(AppointmentService.self) private var appointments
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var setup
    @Environment(MessageService.self) private var messages

    init(request: ClientMessageRequest) {
        self.request = request
    }

    var body: some View {
        ClientMessageContentView(
            request: request, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        )
    }
}
