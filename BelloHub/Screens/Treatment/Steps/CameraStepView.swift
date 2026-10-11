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
/// When this client has an earlier photo, it can be laid over the preview as a framing reference (routine item 11,
/// `FramingReferenceRules`): "Show previous photo" with an opacity slider and a short guide. The reference lives in
/// memory only and is never part of the photo taken.
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
    /// The framing reference, decrypted in memory; nil when the client has no earlier photo.
    @State private var reference: Data?
    @State private var showsReference = true
    @State private var referenceOpacity = Self.defaultReferenceOpacity
    @State private var isTaking = false
    @State private var isReady = false

    /// Light enough to see the live picture through it, strong enough to find the outline.
    private static let defaultReferenceOpacity = 0.35
    private static let referenceOpacityRange = 0.15...0.6

    var body: some View {
        content
            .background(Palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Text(kind.title))
            .task { await prepare() }
            .task { reference = await viewModel.framingReference(for: kind) }
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
                    if showsReference, let reference {
                        DataImage(data: reference).opacity(referenceOpacity)
                            .allowsHitTesting(false).accessibilityHidden(true)
                        FramingGuides().allowsHitTesting(false)
                    }
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .padding(.horizontal, Spacing.gutter)
                .accessibilityLabel(Text("treatmentFlow.camera.preview"))
                .accessibilityIdentifier("treatmentFlow.camera.preview")
                Text("treatmentFlow.camera.private").font(Typography.meta).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center).padding(.horizontal, Spacing.gutter)
                if reference != nil, showsReference {
                    Text("treatmentFlow.camera.reference.guide").font(Typography.footnote).foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center).padding(.horizontal, Spacing.gutter)
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { controls }
    }

    private var controls: some View {
        FlowBottomBar {
            if reference != nil { referenceControls }
            HStack(spacing: Spacing.md) {
                if camera.supportsFlash {
                    Toggle(isOn: $flashOn) { Image(icon: .bolt) }
                        .toggleStyle(.button)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(Text("treatmentFlow.camera.flash"))
                        .accessibilityIdentifier("treatmentFlow.camera.flashToggle")
                        .onChange(of: flashOn) { _, new in camera.setFlash(new) }
                }
            }
            Button { Task { await take() } } label: { Text("treatmentFlow.camera.capture") }
                .buttonStyle(.belloPrimary)
                .disabled(isTaking || !isReady)
                .accessibilityIdentifier("treatmentFlow.camera.captureButton")
        }
    }

    /// "Show previous photo" and how strongly it shows, pinned above the capture button. They live in the bar, not in
    /// the scrolling content: on a 6.1-inch iPhone the 3:4 preview fills the screen and a card under it sat behind the
    /// bar, out of sight and out of reach. Native switch and slider; the guide stays under the preview.
    @ViewBuilder
    private var referenceControls: some View {
        Toggle(isOn: $showsReference) {
            Text("treatmentFlow.camera.reference.toggle").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
        }
        .tint(Palette.action)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier("treatmentFlow.camera.referenceToggle")
        if showsReference {
            HStack(spacing: Spacing.row) {
                Text("treatmentFlow.camera.reference.opacity").font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
                Slider(value: $referenceOpacity, in: Self.referenceOpacityRange) {
                    Text("treatmentFlow.camera.reference.opacity")
                }
                .tint(Palette.action)
                .accessibilityValue(Text(referenceOpacity.formatted(.percent.precision(.fractionLength(0)))))
                .accessibilityIdentifier("treatmentFlow.camera.referenceOpacity")
            }
            .frame(minHeight: Spacing.touchTarget)
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
