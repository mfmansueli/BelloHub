//
//  VisitDetailsCard.swift
//  BelloHub
//

import SwiftUI

/// Who, what and when: the client, the service (chosen here for a visit with no appointment) and the real day and
/// time of the treatment, which can be earlier than today when she writes an old visit. A future time is not offered.
struct VisitDetailsCard: View {
    @Bindable var viewModel: TreatmentFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.row) {
                Avatar(name: viewModel.client?.name ?? "", id: viewModel.clientID.uuidString, size: 44)
                Text(verbatim: viewModel.client?.name ?? "")
                    .font(Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            service
            DatePicker(
                selection: Binding(get: { viewModel.performedAt }, set: { viewModel.setPerformedAt($0) }),
                in: ...Date(), displayedComponents: [.date, .hourAndMinute]
            ) {
                Text("visitForm.date").font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            .tint(Palette.roseText)
            .disabled(viewModel.isLocked)
            .accessibilityIdentifier("visitForm.date")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("treatmentFlow.visitCard")
    }

    /// The appointment's service is fixed; a visit without one picks from her services (or keeps the generic name).
    @ViewBuilder
    private var service: some View {
        if viewModel.appointment != nil || viewModel.services.isEmpty || viewModel.isLocked {
            HStack {
                Text("visitForm.service").font(Typography.meta).foregroundStyle(Palette.ink2)
                Spacer(minLength: Spacing.sm)
                Text(verbatim: viewModel.serviceName).font(Typography.body).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.trailing)
            }
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("visitForm.service")
        } else {
            Picker(selection: Binding(get: { viewModel.service?.id }, set: { viewModel.selectService($0) })) {
                Text(verbatim: viewModel.names.serviceFallback).tag(UUID?.none)
                ForEach(viewModel.services) { service in
                    Text(verbatim: service.name).tag(UUID?.some(service.id))
                }
            } label: {
                Text("visitForm.service").font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            .pickerStyle(.menu)
            .tint(Palette.roseText)
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("visitForm.servicePicker")
        }
    }
}
