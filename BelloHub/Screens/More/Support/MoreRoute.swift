//
//  MoreRoute.swift
//  BelloHub
//

/// Where the More tab can go, as a typed route on its `NavigationStack` (docs/04-ARCHITECTURE.md section 5). The tab
/// owns the stack and the `navigationDestination`; each case is one screen, and any screen inside the stack can push
/// another with `NavigationLink(value:)`. The `section` groups the cases so the tab's destination switch stays small.
enum MoreRoute: Hashable, Sendable {
    /// 6.1 Services (6.2 ServiceEdit and 6.3 AddOns open from it).
    case services
    /// 6.4 Products.
    case products
    /// 6.7 BookingSettings (6.8 ShareLink, 6.15 NoShowPolicy and 6.16 CancelPolicy open from it).
    case bookingPage
    /// 6.5 Availability.
    case availability
    /// 6.10 Credentials.
    case credentials
    /// 6.11 Team (a static "later" screen, D5).
    case team
    /// 6.9 QuickReplies.
    case quickReplies
    /// 6.12 Tags.
    case tags
    /// 6.13 RecordTemplate.
    case recordTemplate
    /// 6.14 FormTemplates.
    case formTemplates
    /// 7.1 Account (7.2 LanguageRegion opens from it).
    case account
    /// 7.2 LanguageRegion.
    case languageRegion
    /// 7.3 Plan.
    case plan
    /// 7.4 NotificationSettings.
    case notifications
    /// 7.6 Integrations.
    case integrations
    /// 7.7 Privacy (7.8 ExportAll and 7.9 RecoveryKey open from it).
    case privacy
    /// 7.8 ExportAll.
    case exportAll
    /// 7.9 RecoveryKey.
    case recoveryKey
    /// 7.10 Help.
    case help

    enum Section: Hashable, Sendable {
        case business
        case clients
        case messages
        case preferences
        case account
    }

    var section: Section {
        switch self {
        case .services, .products, .bookingPage, .availability, .credentials, .team: .business
        case .tags, .recordTemplate, .formTemplates: .clients
        case .quickReplies: .messages
        case .plan, .notifications, .integrations, .privacy, .exportAll, .recoveryKey, .help: .preferences
        case .account, .languageRegion: .account
        }
    }
}
