//
//  RootView.swift
//  BelloHub
//

import SwiftUI

/// State gate for the whole app: welcome → sign-in → setup → locked → app (`RootGate`). It creates the app-session
/// Services once, as `@State`, and distributes them with `.environment(...)`; screens never create their own.
struct RootView: View {
    @State private var session: SessionService
    @State private var keyManager: KeyManager
    @State private var appLock: AppLockService
    @State private var permissions: PermissionService
    @State private var vault: VaultService
    @State private var profile: ProfileService
    @State private var model: RootViewModel
    private let regions: RegionCatalog
    private let dependencies: AppDependencies

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let dependencies = AppDependencies.make()
        self.dependencies = dependencies
        _session = State(initialValue: dependencies.session)
        _keyManager = State(initialValue: dependencies.keyManager)
        _appLock = State(initialValue: dependencies.appLock)
        _permissions = State(initialValue: dependencies.permissions)
        _vault = State(initialValue: dependencies.vault)
        _profile = State(initialValue: dependencies.profile)
        _model = State(initialValue: RootViewModel(
            session: dependencies.session, appLock: dependencies.appLock, keyManager: dependencies.keyManager,
            profile: dependencies.profile
        ))
        regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
    }

    var body: some View {
        ZStack {
            content
            if scenePhase != .active { PrivacyCover() }
        }
        .environment(session)
        .environment(keyManager)
        .environment(appLock)
        .environment(permissions)
        .environment(vault)
        .environment(profile)
        .belloLocaleTypography()
        .disablesAnimationsForUITests()
        .task {
            #if DEBUG
            await UITestSeeding.seedIfRequested(dependencies, options: LaunchOptions.current)
            #endif
            await model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appLock.sceneDidLeave()
            case .active: appLock.sceneDidReturn()
            default: break
            }
        }
        .onChange(of: appLock.isLocked) { wasLocked, isLocked in
            if wasLocked && !isLocked { Task { await model.didUnlock() } }
        }
    }

    // MARK: - Stages

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if LaunchOptions.current.showsDesignCatalog {
            DesignCatalogView(options: LaunchOptions.current)
        } else {
            stage
        }
        #else
        stage
        #endif
    }

    @ViewBuilder
    private var stage: some View {
        if !vault.isAvailable {
            StorageUnavailableView()
        } else {
            switch model.stage {
            case .loading:
                Palette.bg.ignoresSafeArea()
            case .welcome:
                WelcomeView(onGetStarted: { model.choose(.create) }, onSignIn: { model.choose(.existing) })
            case .signIn(let mode):
                SignInView(
                    mode: mode, session: session, regions: regions, initialRegion: initialRegion,
                    onSignedIn: { await model.didSignIn() }, onBack: model.backToWelcome,
                    onSwitchMode: { model.choose(mode == .create ? .existing : .create) }
                )
            case .setup:
                SetupView(
                    profile: profile, regions: regions, onFinished: model.didFinishSetup,
                    onExit: { Task { await model.signOut() } }
                )
            case .locked:
                LockedView()
            case .app:
                MainView(onSignOut: { Task { await model.signOut() } })
            }
        }
    }

    private var initialRegion: RegionPreset {
        let locale = Locale.current
        return regions.preset(
            deviceRegion: locale.region?.identifier, languageCode: locale.language.languageCode?.identifier
        )
    }
}

#Preview {
    RootView()
}
