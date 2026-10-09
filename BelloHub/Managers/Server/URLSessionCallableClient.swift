//
//  URLSessionCallableClient.swift
//  BelloHub
//

import Foundation

/// Calls the functions over HTTPS with the callable wire protocol, with no Functions SDK: the app already carries
/// Firebase
/// Auth for the token, and a plain POST keeps the contract in one readable place (API.md section 1). App Check is not
/// sent yet: enforcement is off on the dev project (D43) and arrives with its own slice.
struct URLSessionCallableClient: CallableClient {
    private let config: ServerConfig
    private let tokens: any IDTokenProviding
    private let transport: any HTTPTransport

    init(
        config: ServerConfig = .current,
        tokens: any IDTokenProviding,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.config = config
        self.tokens = tokens
        self.transport = transport
    }

    func send(function: String, data: Data) async throws -> Data {
        let token = try await tokens.idToken()
        var request = URLRequest(url: config.functionURL(function))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Self.envelope(data)

        let body: Data
        let status: Int
        do {
            let (responseBody, response) = try await transport.send(request)
            body = responseBody
            status = response.statusCode
        } catch {
            throw CallableErrorMapper.error(transport: error)
        }
        if let failure = CallableErrorMapper.error(httpStatus: status, body: body) { throw failure }
        return try Self.result(of: body)
    }

    // MARK: - Wire shape

    /// `{"data": <request>}`; an empty request is `{}`.
    static func envelope(_ data: Data) -> Data {
        var wrapped = Data(#"{"data":"#.utf8)
        wrapped.append(data.isEmpty ? Data("{}".utf8) : data)
        wrapped.append(Data("}".utf8))
        return wrapped
    }

    /// The bytes of `result` from `{"result": ...}`.
    static func result(of body: Data) throws -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let result = object["result"],
              let bytes = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed, .sortedKeys])
        else { throw ServerError.unexpected(code: "RESULT") }
        return bytes
    }
}
