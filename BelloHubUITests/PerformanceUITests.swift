//
//  PerformanceUITests.swift
//  BelloHubUITests
//

import XCTest

/// The performance budgets of docs/13-TESTING-QUALITY.md section 6, measured with XCTest metrics (S12): cold start,
/// scrolling and searching 2,000 clients, and memory while 200 photos scroll by on a client's history. Not a check that
/// can fail a plan on a slow machine: it only runs when asked, like `ColorReviewUITests`:
/// `TEST_RUNNER_BELLO_PERF=1 ONLY_TESTING=BelloHubUITests/PerformanceUITests scripts/test.sh full`.
/// The numbers go to `docs/agent-notes/s8-leftovers.md` (Xcode prints each metric's average in the log).
@MainActor
final class PerformanceUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = true
        guard ProcessInfo.processInfo.environment["BELLO_PERF"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BELLO_PERF=1 to measure the performance budgets")
        }
    }

    /// Budget: cold start to Home ≤ 1.5 s.
    func testColdStartToHome() {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            let app = XCUIApplication()
            app.launchArguments += ["-uiTesting", "-uiSeed", "onboarded"]
            app.launch()
            _ = app.tab(0).waitForExistence(timeout: 20)
            app.terminate()
        }
    }

    /// Budget: the list of 2,000 clients scrolls with no hitch over 8 ms.
    func testScrollingTwoThousandClients() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiPerfClients", "2000"])
        app.openClientsTab()
        let list = app.element("clients.list")
        XCTAssertTrue(list.waitForExistence(timeout: 60), "no client list")
        XCTAssertTrue(app.clientRows.firstMatch.waitForExistence(timeout: 60), "no client row")
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric, XCTOSSignpostMetric.scrollDraggingMetric],
                options: options) {
            list.swipeUp(velocity: .fast)
            stopMeasuring()
            list.swipeDown(velocity: .fast)
        }
    }

    /// Budget: a search over 2,000 clients answers in ≤ 150 ms. The app marks each search with a signpost
    /// (`PerformanceSignposts.clientSearch`), so the metric is the search itself, not the typing.
    func testSearchingTwoThousandClients() {
        let app = XCUIApplication.launchedForUITests(arguments: ["-uiSeed", "onboarded", "-uiPerfClients", "2000"])
        app.openClientsTab()
        XCTAssertTrue(app.clientRows.firstMatch.waitForExistence(timeout: 60), "no client row")
        app.swipeDown()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "no search field")
        field.tap()
        let search = XCTOSSignpostMetric(subsystem: "app.bellohub", category: "performance", name: "clientSearch")
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [search], options: options) {
            field.typeText("9")
            _ = app.clientRows.firstMatch.waitForExistence(timeout: 5)
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
    }

    /// Budget: memory with 200 photos ≤ 250 MB (thumbnails only in strips and grids, full size on demand).
    func testMemoryWithTwoHundredPhotos() {
        let app = XCUIApplication.launchedForUITests(arguments: [
            "-uiSeed", "clientWithHealth", "-uiPerfPhotos", "200", "-uiRoute", "recordHistory"
        ])
        XCTAssertTrue(app.element("recordHistory.overview").waitForExistence(timeout: 120), "no record history")
        // The screen may load before the 200 photos are seeded: pull to refresh until the strip has photos. The strip
        // is found through its photos (the section's identifier is passed down to its children).
        let photos = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'recordHistory.photo.'"))
        for _ in 0..<12 where !photos.firstMatch.waitForExistence(timeout: 5) {
            app.element("recordHistory.overview").swipeDown()
        }
        let strip = photos.firstMatch
        for _ in 0..<6 where !strip.isHittable { app.element("recordHistory.overview").swipeUp() }
        XCTAssertTrue(strip.exists, "no photo on the timeline")
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTMemoryMetric(application: app)], options: options) {
            for _ in 0..<12 { strip.swipeLeft(velocity: .fast) }
            for _ in 0..<12 { strip.swipeRight(velocity: .fast) }
        }
    }
}
