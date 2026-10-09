//
//  ServerConfig.swift
//  BelloHub
//

import Foundation

/// The two addresses the app needs: the functions it calls and the web address of her booking page. Both come from
/// `Config/App.xcconfig` (`BELLO_FUNCTIONS_BASE_URL`, `BELLO_WEB_BASE_URL`) through the Info.plist, so no screen
/// holds an
/// address and a custom domain later is a one-line change (D54).
struct ServerConfig: Equatable, Sendable {
    /// `https://europe-west1-<project>.cloudfunctions.net`: a function lives at `<base>/<name>`.
    let functionsBaseURL: URL
    /// `https://bello-hub.web.app`: her link is `<base>/<slug>`.
    let webBaseURL: URL
    /// The Firebase project whose Firestore the inbox reads (`bookings`, `rescheduleRequests`, `waitlist`,
    /// `inbox/{uid}/items`), under the same rules as the SDK would.
    let projectID: String

    static let functionsKey = "BelloFunctionsBaseURL"
    static let webKey = "BelloWebBaseURL"
    static let projectKey = "BelloFirebaseProjectID"

    /// Used only when the Info.plist has no value (a broken build setting must not crash the app or invent a domain
    /// we do not own): the dev project of D43/D54.
    static let fallback = ServerConfig(
        functionsBaseURL: URL(string: "https://europe-west1-bello-hub.cloudfunctions.net") ?? URL(filePath: "/"),
        webBaseURL: URL(string: "https://bello-hub.web.app") ?? URL(filePath: "/"),
        projectID: "bello-hub"
    )

    /// What this build was configured with.
    static let current = ServerConfig(info: Bundle.main.infoDictionary ?? [:])

    init(functionsBaseURL: URL, webBaseURL: URL, projectID: String = "bello-hub") {
        self.functionsBaseURL = functionsBaseURL
        self.webBaseURL = webBaseURL
        self.projectID = projectID
    }

    /// Reads the two keys of an Info.plist dictionary; a missing or malformed value falls back one by one.
    init(info: [String: Any]) {
        functionsBaseURL = Self.url(info[Self.functionsKey]) ?? Self.fallback.functionsBaseURL
        webBaseURL = Self.url(info[Self.webKey]) ?? Self.fallback.webBaseURL
        let project = (info[Self.projectKey] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        projectID = project.isEmpty ? Self.fallback.projectID : project
    }

    /// The address of one function.
    func functionURL(_ name: String) -> URL {
        functionsBaseURL.appending(path: name)
    }

    /// `https://firestore.googleapis.com/v1/projects/<project>/databases/(default)/documents`: the REST root of the
    /// documents the owner may read (API.md section 8).
    var firestoreDocumentsURL: URL {
        (URL(string: "https://firestore.googleapis.com/v1/projects/") ?? URL(filePath: "/"))
            .appending(path: projectID).appending(path: "databases/(default)/documents")
    }

    private static func url(_ value: Any?) -> URL? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
              let url = URL(string: text), url.scheme == "https" || url.scheme == "http", url.host() != nil
        else { return nil }
        return url
    }
}
