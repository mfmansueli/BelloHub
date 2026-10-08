//
//  SignInView.swift
//  BelloHub
//

import SwiftUI

/// 1.2 SignIn. Phone, then the six-digit code. The same screen opens a new workspace and an existing one; only the
/// heading and the link at the bottom change.
struct SignInView: View {
    let mode: SignInMode
    let onBack: () -> Void
    let onSwitchMode: () -> Void

    @State private var viewModel: SignInViewModel
    @Environment(\.locale) private var locale
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case phone
        case code
    }

    init(
        mode: SignInMode, session: SessionService, regions: RegionCatalog, initialRegion: RegionPreset,
        onSignedIn: @escaping @MainActor () async -> Void, onBack: @escaping () -> Void,
        onSwitchMode: @escaping () -> Void
    ) {
        self.mode = mode
        self.onBack = onBack
        self.onSwitchMode = onSwitchMode
        _viewModel = State(initialValue: SignInViewModel(
            session: session, catalog: regions, initialRegion: initialRegion, onSignedIn: onSignedIn
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                topBar
                header
                switch viewModel.step {
                case .phone: phoneStep
                case .code: codeStep
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { GlowBackdrop() }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onChange(of: viewModel.step) { _, step in focus = step == .code ? .code : .phone }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Button(action: viewModel.step == .code ? viewModel.useDifferentNumber : onBack) {
                Image(icon: .back)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .accessibilityLabel(Text("common.back"))
            .accessibilityIdentifier("signIn.backButton")
            Spacer()
            BrandLockup(markSize: 40)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("signIn.title")
            Text(subtitle)
                .font(Typography.body)
                .foregroundStyle(Palette.ink2)
        }
    }

    private var title: LocalizedStringKey {
        switch viewModel.step {
        case .code: "onb.signIn.code.title"
        case .phone: mode == .create ? "onb.signIn.create.title" : "onb.signIn.title"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch viewModel.step {
        case .code: "onb.signIn.code.subtitle"
        case .phone: mode == .create ? "onb.signIn.create.subtitle" : "onb.signIn.subtitle"
        }
    }

    // MARK: - Phone step

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.row) {
                SignInRegionMenu(region: $viewModel.region, regions: viewModel.regions)
                TextField(text: $viewModel.phoneInput, prompt: .prompt("onb.signIn.phone.label")) {
                    Text("onb.signIn.phone.label")
                }
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focus, equals: .phone)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 56)
                    .background(Palette.surface, in: fieldShape)
                    .overlay { fieldShape.strokeBorder(phoneBorder, lineWidth: 1.5) }
                    .accessibilityIdentifier("signIn.phoneField")
            }
            if let problem = viewModel.phoneProblem {
                Text(message(for: problem)).font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("signIn.phoneError")
            } else if let error = viewModel.authError {
                errorText(error)
            } else {
                Text("onb.signIn.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    // MARK: - Code step

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let number = viewModel.e164 {
                let shown = BidiIsolate.wrapLeftToRight(PhoneFormatter(catalog: catalog).international(number))
                Text(LocalizedStringResource(
                    "onb.signIn.code.sent", defaultValue: "We sent a 6-digit code to \(shown)."
                ).localized(in: locale))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            // The label sits above the field, not inside it: a long placeholder at 28 pt would be cut off in a
            // single-line field at the larger text sizes.
            Text("onb.signIn.code.label").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            TextField(text: codeBinding, prompt: Text(verbatim: "")) { Text("onb.signIn.code.label") }
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focus, equals: .code)
                .multilineTextAlignment(.center)
                .font(Typography.title.monospacedDigit())
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 64)
                .background(Palette.surface, in: fieldShape)
                .overlay { fieldShape.strokeBorder(codeBorder, lineWidth: 1.5) }
                .accessibilityLabel(Text("onb.signIn.code.label"))
                .accessibilityIdentifier("signIn.codeField")
            if let error = viewModel.authError { errorText(error) }
            resendRow
        }
    }

    private var resendRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let seconds = viewModel.secondsUntilResend
            Button(action: viewModel.resend) {
                if seconds > 0 {
                    Text(LocalizedStringResource("onb.signIn.resendIn", defaultValue: "Send again in \(seconds) s")
                        .localized(in: locale))
                } else {
                    Text("onb.signIn.resend")
                }
            }
            .buttonStyle(.belloTertiary)
            .disabled(seconds > 0 || viewModel.isWorking)
            .accessibilityIdentifier("signIn.resendButton")
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            switch viewModel.step {
            case .phone:
                Button(action: viewModel.sendCode) { Text("onb.signIn.send") }
                    .buttonStyle(.belloPrimary)
                    .disabled(!viewModel.canSend)
                    .accessibilityIdentifier("signIn.sendButton")
                FlowLayout(spacing: Spacing.xs, lineSpacing: 0, isCentered: true) {
                    switchPrompt
                    switchLink
                }
            case .code:
                Button(action: viewModel.verify) { Text("onb.signIn.verify") }
                    .buttonStyle(.belloPrimary)
                    .disabled(!viewModel.canVerify)
                    .accessibilityIdentifier("signIn.verifyButton")
                Button(action: viewModel.useDifferentNumber) { Text("onb.signIn.differentNumber") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("signIn.differentNumberButton")
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .motionBar()
    }

    private var switchPrompt: some View {
        Text(mode == .create ? "onb.welcome.haveAccount" : "onb.signIn.newPrompt")
            .font(Typography.meta).foregroundStyle(Palette.ink2)
    }

    private var switchLink: some View {
        Button(action: onSwitchMode) {
            Text(mode == .create ? "onb.welcome.signIn" : "onb.signIn.create")
                .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
        }
        .accessibilityIdentifier("signIn.switchModeButton")
    }

    // MARK: - Helpers

    private var catalog: RegionCatalog { RegionCatalog(presets: viewModel.regions) }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }

    private var phoneBorder: Color {
        viewModel.phoneProblem == nil && viewModel.authError == nil ? Palette.fieldBorder : Palette.coralText
    }

    private var codeBorder: Color {
        viewModel.authError == nil ? Palette.fieldBorder : Palette.coralText
    }

    private var codeBinding: Binding<String> {
        Binding(get: { viewModel.code }, set: { viewModel.codeChanged($0) })
    }

    private func errorText(_ error: AuthError) -> some View {
        Text(message(for: error))
            .font(Typography.footnote)
            .foregroundStyle(Palette.coralText)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("signIn.error")
    }

    private func message(for error: AuthError) -> LocalizedStringKey {
        switch error {
        case .invalidPhone: "onb.signIn.error.phone"
        case .invalidCode: "onb.signIn.error.code"
        case .tooManyAttempts: "onb.signIn.error.tooMany"
        case .network: "onb.signIn.error.network"
        case .unavailable: "onb.signIn.error.unavailable"
        }
    }

    private func message(for failure: PhoneNormalizer.Failure) -> LocalizedStringKey {
        switch failure {
        case .empty, .tooShort: "onb.signIn.error.phoneShort"
        case .tooLong, .implausibleLength: "onb.signIn.error.phone"
        }
    }

}
