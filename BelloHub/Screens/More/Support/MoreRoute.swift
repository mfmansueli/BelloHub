//
//  MoreRoute.swift
//  BelloHub
//

/// Where the More tab can go, as a typed route on its `NavigationStack` (docs/04-ARCHITECTURE.md section 5). The tab
/// owns the stack and the `navigationDestination`; each case is one screen, and any screen inside the stack can push
/// another with `NavigationLink(value:)`. Later stages add their cases here (account and privacy in S10).
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
}
