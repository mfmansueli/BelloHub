//
//  FakeImmediateNotifier.swift
//  BelloHubTests
//

@testable import BelloHub
import os

/// The local alerts the app would raise, recorded instead of shown, so a test can check how many there were and that
/// no name is in them.
final class FakeImmediateNotifier: ImmediateNotifying, Sendable {
    struct Post: Equatable {
        let id: String
        let threadID: String
        let title: String
        let body: String
    }

    private let state = OSAllocatedUnfairLock(initialState: [Post]())

    var posts: [Post] { state.withLock { $0 } }

    func post(id: String, threadID: String, title: String, body: String) async {
        state.withLock { $0.append(Post(id: id, threadID: threadID, title: title, body: body)) }
    }
}
