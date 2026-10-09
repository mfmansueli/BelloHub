//
//  BookingLink.swift
//  BelloHub
//

import Foundation

/// Her public booking link: the web app's base address plus her slug. The base comes from configuration
/// (`BELLO_WEB_BASE_URL`, docs/02-DECISIONS.md O15); the value here is only built from it.
struct BookingLink: Equatable, Sendable {
    /// Where the web app lives: `BELLO_WEB_BASE_URL` through `ServerConfig` (D54: the Firebase Hosting address until a
    /// custom domain exists).
    static let defaultBaseURL = ServerConfig.current.webBaseURL

    let baseURL: URL
    let slug: String

    init(slug: String, baseURL: URL = BookingLink.defaultBaseURL) {
        self.slug = slug
        self.baseURL = baseURL
    }

    /// `https://bello-hub.web.app/maria`.
    var url: URL {
        baseURL.appending(path: slug)
    }

    /// `bello-hub.web.app/maria`: what is shown to people and typed into a bio.
    var display: String {
        "\(baseURL.host() ?? baseURL.absoluteString)/\(slug)"
    }

    /// The host part alone, shown in front of the field where she types the slug.
    var host: String {
        baseURL.host() ?? baseURL.absoluteString
    }
}
