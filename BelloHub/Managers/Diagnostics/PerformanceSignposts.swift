//
//  PerformanceSignposts.swift
//  BelloHub
//

import os

/// Intervals that the performance budgets measure (docs/13-TESTING-QUALITY.md section 6; `PerformanceUITests` reads
/// them with `XCTOSSignpostMetric`, Instruments shows them too). Names only, never a value: no client text ever goes
/// into a signpost.
enum PerformanceSignposts {
    static let subsystem = "app.bellohub"
    static let category = "performance"
    static let signposter = OSSignposter(subsystem: subsystem, category: category)

    /// One run of the Clients search over the whole list.
    static let clientSearch: StaticString = "clientSearch"
}
