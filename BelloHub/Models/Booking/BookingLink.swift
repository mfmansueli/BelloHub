//
//  BookingLink.swift
//  BelloHub
//

import Foundation

/// Her public booking link: the web app's base address plus her slug. The base comes from configuration
/// (`BELLO_WEB_BASE_URL`, docs/02-DECISIONS.md O15); the value here is only built from it.
struct BookingLink: Equatable, Sendable {
    /// Where the web app lives while the domain is pending: the planned production address.
    static let defaultBaseURL = URL(string: "https://bellohub.app") ?? URL(filePath: "/")

    let baseURL: URL
    let slug: String

    init(slug: String, baseURL: URL = BookingLink.defaultBaseURL) {
        self.slug = slug
        self.baseURL = baseURL
    }

    /// `https://bellohub.app/maria`.
    var url: URL {
        baseURL.appending(path: slug)
    }

    /// `bellohub.app/maria`: what is shown to people and typed into a bio.
    var display: String {
        "\(baseURL.host() ?? baseURL.absoluteString)/\(slug)"
    }

    /// The host part alone, shown in front of the field where she types the slug.
    var host: String {
        baseURL.host() ?? baseURL.absoluteString
    }
}
