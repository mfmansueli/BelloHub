//
//  HTTPTransport.swift
//  BelloHub
//

import Foundation

/// One HTTP round trip, so `URLSessionCallableClient` is tested with a fake and the real session is only wired in the
/// app. Throws whatever the transport throws (`URLError` offline).
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
