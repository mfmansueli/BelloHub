//
//  PublishFailureNotice.swift
//  BelloHub
//

import SwiftUI

/// The notice for a page that could not be published: what failed, whether the page already online keeps working, and
/// "Try again" when trying again can help. Shared by the booking page settings and Share your link.
struct PublishFailureNotice: View {
    let failure: PublishFailure
    let wasOnline: Bool
    let onRetry: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        ErrorNotice(
            message: PublishStatusText.failure(failure, wasOnline: wasOnline).resolved(in: locale),
            actionTitle: PublishStatusText.offersRetry(failure) ? "bookingSetup.retry" : nil,
            action: PublishStatusText.offersRetry(failure) ? onRetry : nil
        )
    }
}

#Preview {
    PublishFailureNotice(failure: .offline, wasOnline: true, onRetry: {})
        .padding()
}
