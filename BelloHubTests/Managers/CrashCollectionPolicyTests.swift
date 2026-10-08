//
//  CrashCollectionPolicyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("CrashCollectionPolicy")
struct CrashCollectionPolicyTests {
    @Test("Release builds always send crash reports")
    func releaseAlwaysCollects() {
        #expect(CrashCollectionPolicy.isCollectionEnabled(isDebugBuild: false, arguments: []))
    }

    @Test("Debug builds stay silent by default")
    func debugIsSilentByDefault() {
        #expect(!CrashCollectionPolicy.isCollectionEnabled(isDebugBuild: true, arguments: []))
    }

    @Test("Debug builds send reports only when the override argument is present")
    func debugCollectsWithOverride() {
        let arguments = ["-uiTesting", CrashCollectionPolicy.enableInDebugArgument]

        #expect(CrashCollectionPolicy.isCollectionEnabled(isDebugBuild: true, arguments: arguments))
    }

    @Test("The test crash argument alone does not turn collection on")
    func testCrashDoesNotEnableCollection() {
        let arguments = [CrashCollectionPolicy.testCrashArgument]

        #expect(!CrashCollectionPolicy.isCollectionEnabled(isDebugBuild: true, arguments: arguments))
    }
}
