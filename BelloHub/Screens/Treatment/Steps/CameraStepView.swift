//
//  CameraStepView.swift
//  BelloHub
//

import SwiftUI
import UIKit

/// 5.8 Camera: the app's own camera, so a photo is saved only in Bello and never in the camera roll. The permission
/// goes
/// through `PermissionService`; a denied permission gets an explanation and the way to Settings (and the library stays
/// available on the previous screen). After a shot she reviews it, chooses who can see it, and retakes or saves.
struct CameraStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let kind: PhotoKind

    @Environment(PermissionService.self) private var permissions
    @Environment(\.cameraCapture) private var camera
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SystemSettingsOpener()
    @State private var shot: Data?
    @State private var visibility = PhotoVisibility.professionalOnly
    @State private var flashOn = false
    @State private var showsGhost = true
    @State private var isTaking = false
    @State private var isReady = false

    var body: some View {
        content
            .background(Palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Text(kind.title))
            .task { await prepare() }
            .onDisappear { camera.stop() }
    }

    @ViewBuilder
    private var content: some View {
        if let shot {
            review(shot)
        } else if !camera.hasCamera {
            unavailable
        } else {
            switch permissions.status(of: .camera) {
            case .denied: denied
            case .notDetermined: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .granted: live
            }
        }
    }

    // MARK: - Live

    /// The preview and the note scroll above a pinned bar: at the largest text sizes in German the note and the button
    /// need more height than the 3:4 preview leaves on a screen that does not scroll.
    private var live: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ZStack {
                    CameraPreview(camera: camera)
                    if showsGhost, let ghost = viewModel.ghostThumbnail(for: kind) {
                        DataImage(data: ghost).opacity(0.35).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .padding(.horizontal, Spacing.gutter)
                .accessibilityLabel(Text("treatmentFlow.camera.preview"))
                .accessibilityIdentifier("treatmentFlow.camera.preview")
                Text("treatmentFlow.camera.private").font(Typography.meta).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center).padding(.horizontal, Spacing.gutter)
            }
            .padding(.vertical, Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { controls }
    }

    private var controls: some View {
        FlowBottomBar {
            HStack(spacing: Spacing.md) {
                if camera.supportsFlash {
                    Toggle(isOn: $flashOn) { Image(icon: .bolt) }
                        .toggleStyle(.button)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(Text("treatmentFlow.camera.flash"))
                        .accessibilityIdentifier("treatmentFlow.camera.flashToggle")
                        .onChange(of: flashOn) { _, new in camera.setFlash(new) }
                }
                if viewModel.ghostThumbnail(for: kind) != nil {
                    Toggle(isOn: $showsGhost) { Text("treatmentFlow.camera.ghost") }
                        .toggleStyle(.button)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("treatmentFlow.camera.ghostToggle")
                }
            }
            Button { Task { await take() } } label: { Text("treatmentFlow.camera.capture") }
                .buttonStyle(.belloPrimary)
                .disabled(isTaking || !isReady)
                .accessibilityIdentifier("treatmentFlow.camera.captureButton")
        }
    }

    // MARK: - Review

    private func review(_ data: Data) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                DataImage(data: data)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    .accessibilityLabel(Text("treatmentFlow.camera.review"))
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("treatmentFlow.camera.who").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    Picker(selection: $visibility, label: Text("treatmentFlow.camera.who")) {
                        ForEach(viewModel.allowedVisibilities, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("treatmentFlow.camera.visibilityPicker")
                    if !viewModel.hasPhotoConsent {
                        Text("treatmentFlow.camera.needsConsent").font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                }
                if let failure = viewModel.failure { TreatmentFailureNotice(failure: failure) }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("treatmentFlow.camera.reviewScreen")
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button { Task { await save(data) } } label: { Text("treatmentFlow.camera.save") }
                    .buttonStyle(.belloPrimary)
                    .disabled(viewModel.isProcessingPhoto)
                    .accessibilityIdentifier("treatmentFlow.camera.saveButton")
                Button { shot = nil; viewModel.failure = nil } label: { Text("treatmentFlow.camera.retake") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("treatmentFlow.camera.retakeButton")
            }
        }
    }

    // MARK: - Unavailable and denied

    private var unavailable: some View {
        EmptyState(
            icon: .camera, title: "treatmentFlow.camera.unavailable.title",
            message: "treatmentFlow.camera.unavailable.message"
        )
        .accessibilityIdentifier("treatmentFlow.camera.unavailable")
    }

    private var denied: some View {
        VStack(spacing: Spacing.lg) {
            EmptyState(
                icon: .camera, title: "treatmentFlow.camera.denied.title",
                message: "treatmentFlow.camera.denied.message"
            )
            Button { settings.openSettings() } label: { Text("treatmentFlow.camera.denied.settings") }
                .buttonStyle(.belloPrimary)
                .padding(.horizontal, Spacing.gutter)
                .accessibilityIdentifier("treatmentFlow.camera.settingsButton")
            Button { dismiss() } label: { Text("treatmentFlow.camera.denied.back") }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("treatmentFlow.camera.backButton")
        }
        .accessibilityIdentifier("treatmentFlow.camera.denied")
    }

    // MARK: - Actions

    private func prepare() async {
        guard camera.hasCamera else { return }
        await permissions.refresh()
        if permissions.status(of: .camera) == .notDetermined { await permissions.request(.camera) }
        guard permissions.status(of: .camera) == .granted else { return }
        await camera.start()
        isReady = true
    }

    private func take() async {
        isTaking = true
        defer { isTaking = false }
        do {
            shot = try await camera.capture()
            viewModel.failure = nil
        } catch {
            viewModel.failure = .photo
        }
    }

    private func save(_ data: Data) async {
        if await viewModel.addPhoto(data, kind: kind, visibility: visibility) { dismiss() }
    }
}
