//
//  QuickAccessItem.swift
//  BelloHub
//

/// What the quick access sheet on Home opens, one tap from her avatar: the settings that keep the business running.
/// Each item opens the same screen as in More, on the More tab, so there is one screen per setting and Back leads
/// where it would in More.
enum QuickAccessItem: String, CaseIterable, Identifiable, Sendable {
    case bookingPage
    case services
    case availability
    case products
    case recordFields
    case plan
    case notifications
    case languageRegion

    var id: String { rawValue }

    /// The business: what clients book and when, and what she writes after a visit.
    static let business: [QuickAccessItem] = [.bookingPage, .services, .availability, .products, .recordFields]

    /// Her preferences.
    static let preferences: [QuickAccessItem] = [.plan, .notifications, .languageRegion]

    /// The More screens pushed for this item, in order. Language and region lives under Account in More.
    var path: [MoreRoute] {
        switch self {
        case .bookingPage: [.bookingPage]
        case .services: [.services]
        case .availability: [.availability]
        case .products: [.products]
        case .recordFields: [.recordTemplate]
        case .plan: [.plan]
        case .notifications: [.notifications]
        case .languageRegion: [.account, .languageRegion]
        }
    }

    /// "home.quickAccess.services", the accessibility identifier of the row.
    var identifier: String { "home.quickAccess.\(rawValue)" }
}
