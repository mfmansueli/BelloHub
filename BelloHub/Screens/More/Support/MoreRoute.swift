//
//  MoreRoute.swift
//  BelloHub
//

/// Where the More tab can go, as a typed route on its `NavigationStack` (docs/04-ARCHITECTURE.md section 5). The tab
/// owns the stack and the `navigationDestination`; each case is one screen, and any screen inside the stack can push
/// another with `NavigationLink(value:)`. Later stages add their cases here (services, booking page and availability
/// in S5, account and privacy in S10).
enum MoreRoute: Hashable, Sendable {
    /// 6.12 Tags.
    case tags
    /// 6.13 RecordTemplate.
    case recordTemplate
    /// 6.14 FormTemplates.
    case formTemplates
}
