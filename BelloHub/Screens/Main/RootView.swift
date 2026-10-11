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
    @State private var registration: ClientRegistrationService
    @State private var bookingSetup: BookingSetupService
    @State private var appointments: AppointmentService
    @State private var subscription: SubscriptionService
    @State private var recoveryKey: RecoveryKeyService
    @State private var account: AccountService
    @State private var notificationSettings: NotificationSettingsService
    @State private var calendar: CalendarIntegrationService
    @State private var export: DataExportService
    @State private var timeBlocks: TimeBlockService
    @State private var messages: MessageService
    @State private var publishing: PublishingService
    @State private var agendaDigest: AgendaDigestService
    @State private var notifications: NotificationService
    @State private var bookingSync: BookingSyncService
    @State private var mailbox: MailboxService
    @State private var push: PushService
    @State private var clientDeletion: ClientDataDeletionService
    @State private var language: InterfaceLanguageService
    @State private var navigation: MainNavigation
    @State private var followUpQueue: FollowUpQueueService
    @State private var timeZoneNotice: TimeZoneNoticeService
    @State private var model: RootViewModel
    private let regions: RegionCatalog
    private let dependencies: AppDependencies

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let dependencies = AppDependencies.shared
        self.dependencies = dependencies
        _session = State(initialValue: dependencies.session)
        _keyManager = State(initialValue: dependencies.keyManager)
        _appLock = State(initialValue: dependencies.appLock)
        _permissions = State(initialValue: dependencies.permissions)
        _vault = State(initialValue: dependencies.vault)
        _profile = State(initialValue: dependencies.profile)
        _registration = State(initialValue: dependencies.registration)
        _bookingSetup = State(initialValue: dependencies.bookingSetup)
        _appointments = State(initialValue: dependencies.appointments)
        _subscription = State(initialValue: dependencies.subscription)
        _recoveryKey = State(initialValue: dependencies.recoveryKey)
        _account = State(initialValue: dependencies.account)
        _notificationSettings = State(initialValue: dependencies.notificationSettings)
        _calendar = State(initialValue: dependencies.calendar)
        _export = State(initialValue: dependencies.export)
        _timeBlocks = State(initialValue: dependencies.timeBlocks)
        _messages = State(initialValue: dependencies.messages)
        _publishing = State(initialValue: dependencies.publishing)
        _agendaDigest = State(initialValue: dependencies.agendaDigest)
        _notifications = State(initialValue: dependencies.notifications)
        _bookingSync = State(initialValue: dependencies.inbox.bookings)
        _mailbox = State(initialValue: dependencies.inbox.mailbox)
        _push = State(initialValue: dependencies.inbox.push)
        _clientDeletion = State(initialValue: dependencies.inbox.clientDeletion)
        _language = State(initialValue: dependencies.language)
        #if DEBUG
        let initialTab = LaunchOptions.current.initialTab.flatMap(MainTab.init(rawValue:)) ?? .home
        _navigation = State(initialValue: MainNavigation(selection: initialTab))
        #else
        _navigation = State(initialValue: MainNavigation())
        #endif
        _followUpQueue = State(initialValue: FollowUpQueueService(
            defaults: dependencies.defaults, vault: dependencies.vault
        ))
        let regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
        #if DEBUG
        let options = LaunchOptions.current
        let showsTimeZoneNotice = !options.isUITesting || options.showsTimeZoneNotice
        #else
        let showsTimeZoneNotice = true
        #endif
        _timeZoneNotice = State(initialValue: TimeZoneNoticeService(
            defaults: dependencies.defaults, regions: regions, isEnabled: showsTimeZoneNotice
        ))
        _model = State(initialValue: RootViewModel(
            session: dependencies.session, appLock: dependencies.appLock, keyManager: dependencies.keyManager,
            profile: dependencies.profile
        ))
        self.regions = regions
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
        .environment(registration)
        .environment(bookingSetup)
        .environment(appointments)
        .environment(timeBlocks)
        .environment(messages)
        .environment(agendaDigest)
        .environment(notifications)
        .environment(bookingSync)
        .environment(mailbox)
        .environment(push)
        .environment(clientDeletion)
        .treatmentTools(dependencies.treatmentTools)
        .environment(publishing)
        .environment(subscription)
        .environment(recoveryKey)
        .environment(account)
        .environment(notificationSettings)
        .environment(calendar)
        .environment(export)
        .environment(language)
        .environment(navigation)
        .environment(followUpQueue)
        .environment(timeZoneNotice)
        .belloLocaleTypography()
        // The interface language, above every stage, the privacy cover and the lock screen: sheets, alerts, menus and
        // full-screen covers inherit it, and a change re-renders what is open without losing its place.
        .environment(\.locale, language.locale)
        .environment(\.layoutDirection, language.layoutDirection)
        .disablesAnimationsForUITests()
        .task {
            #if DEBUG
            await UITestSeeding.seedIfRequested(dependencies, options: LaunchOptions.current)
            #endif
            await model.start()
            await subscription.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appLock.sceneDidLeave()
            case .active: appLock.sceneDidReturn()
            default: break
            }
        }
        .onChange(of: model.stage) { _, stage in
            // Her hours, policies and messages leave memory when the app locks or she signs out; her page keeps
            // publishing only while the app is open and unlocked.
            if stage == .app, let userID = session.user?.id {
                publishing.start(userID: userID)
                // The inbox follows the unlocked session: bookings first (the mailbox matches forms to them).
                bookingSync.startListening(userId: userID)
                mailbox.startListening(userId: userID)
                push.startListening(userId: userID)
                followUpQueue.start(userID: userID)
                timeZoneNotice.start(userID: userID)
            } else if stage != .app {
                followUpQueue.stop()
                timeZoneNotice.stop()
                bookingSetup.clear()
                publishing.clear()
                agendaDigest.stopListening()
                notifications.stopListening()
                calendar.stopListening()
                push.stopListening()
                mailbox.stopListening()
                bookingSync.stopListening()
            }
            // Nothing of hers stays scheduled once she signs out (a lock only pauses the observation).
            if stage.isSignedOut {
                navigation.reset()
                Task { await notifications.removeAll() }
                // Her visits leave the iPhone's calendar too; the switch is a device preference and stays.
                Task { await calendar.removeMirror() }
            }
        }
        .onChange(of: session.user?.id) { previous, current in
            if let previous, current == nil {
                publishing.clearForSignOut(userID: previous)
                push.clearForSignOut(userID: previous)
                mailbox.clearForSignOut(userID: previous)
                bookingSync.clearForSignOut(userID: previous)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the foreground: what arrived while the app was away.
            if phase == .active, model.stage == .app {
                // She may have landed in another zone, or changed it in Settings, while the app was away.
                timeZoneNotice.refreshPhoneZone()
                bookingSync.syncNow()
                mailbox.syncNow()
            }
        }
        .onChange(of: language.localization) {
            // What she reads outside the app follows too: the local notifications and the pushes the server writes.
            Task { await notifications.reschedule() }
            push.interfaceLanguageDidChange()
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
                WelcomeView(
                    session: session, onSignedIn: { await model.didSignIn() }, onUsePhone: { model.choose(.create) }
                )
            case .signIn(let mode):
                SignInView(
                    mode: mode, session: session, regions: regions, initialRegion: initialRegion,
                    onSignedIn: { await model.didSignIn() }, onBack: model.backToWelcome,
                    onSwitchMode: { model.choose(mode == .create ? .existing : .create) }
                )
            case .setup:
                SetupView(
                    profile: profile, regions: regions, suggestedName: session.user?.displayName,
                    progress: setupProgress,
                    onFinished: model.didFinishSetup,
                    onExit: { Task { await model.signOut() } }
                )
            case .locked:
                LockedView()
            case .app:
                app
            }
        }
    }

    @ViewBuilder
    private var app: some View {
        #if DEBUG
        if let route = LaunchOptions.current.route {
            if route == "appointments" { AppointmentDebugRoute() } else { HealthDebugRoute(route: route) }
        } else {
            mainView
        }
        #else
        mainView
        #endif
    }

    /// Built again when the interface language changes, so the parts iOS draws from SwiftUI (navigation titles, tab
    /// names, toolbars) change with the content; `MainNavigation` keeps the tab and the More stack, so she stays where
    /// she was.
    private var mainView: some View {
        MainView(onSignOut: { Task { await model.signOut() } })
            .id(language.localization)
    }

    /// Her setup resumes where she left it after a relaunch (per user, in the app's defaults).
    private var setupProgress: OnboardingProgressStore? {
        session.user.map { OnboardingProgressStore(defaults: dependencies.defaults, userID: $0.id) }
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
