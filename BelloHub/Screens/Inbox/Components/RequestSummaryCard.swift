//
//  RequestSummaryCard.swift
//  BelloHub
//

import SwiftUI

/// The client, the service and the time a request is about, and the note the client wrote (2.10, 2.11). The time part
/// is the caller's (one time for a booking, "now" and "asks for" for a reschedule). The header and the note are one
/// element each for VoiceOver.
struct RequestSummaryCard<Times: View>: View {
    let clientName: String
    let serviceLine: String
    let note: String?
    let identifier: String
    @ViewBuilder var times: Times

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.row) {
                Avatar(name: clientName, id: clientName, size: 52)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: clientName).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: serviceLine).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("\(identifier).client")
            times
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            if let note, !note.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("inbox.note").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    Text(verbatim: note)
                        .font(Typography.body).foregroundStyle(Palette.sageText)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("\(identifier).note")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
    }
}
