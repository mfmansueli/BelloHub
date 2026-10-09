//
//  ServerConfigTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ServerConfig")
struct ServerConfigTests {
    @Test("Both addresses are read from the Info.plist keys")
    func readsBoth() {
        let config = ServerConfig(info: [
            ServerConfig.functionsKey: "https://europe-west1-demo.cloudfunctions.net",
            ServerConfig.webKey: "https://demo.web.app"
        ])
        #expect(config.functionsBaseURL.absoluteString == "https://europe-west1-demo.cloudfunctions.net")
        #expect(config.webBaseURL.absoluteString == "https://demo.web.app")
    }

    @Test("A missing, empty or malformed value falls back one by one", arguments: [
        nil, "", "   ", "not a url", "ftp://example.com", "https://", "/relative/path"
    ] as [String?])
    func fallsBack(value: String?) {
        var info: [String: Any] = [ServerConfig.functionsKey: "https://europe-west1-demo.cloudfunctions.net"]
        if let value { info[ServerConfig.webKey] = value }
        let config = ServerConfig(info: info)
        #expect(config.webBaseURL == ServerConfig.fallback.webBaseURL)
        #expect(config.functionsBaseURL.host() == "europe-west1-demo.cloudfunctions.net")
    }

    @Test("A function lives at the base address plus its name")
    func functionURL() {
        let config = ServerConfig(info: [ServerConfig.functionsKey: "https://example.test"])
        #expect(config.functionURL("publishProfile").absoluteString == "https://example.test/publishProfile")
    }

    @Test("This build is configured with the dev project's addresses (D54), not a hard-coded domain")
    func buildSettings() {
        let current = ServerConfig.current
        #expect(current.webBaseURL.absoluteString == "https://bello-hub.web.app")
        #expect(current.functionsBaseURL.absoluteString == "https://europe-west1-bello-hub.cloudfunctions.net")
    }
}
