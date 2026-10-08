//
//  ClientSensitiveFields.swift
//  BelloHub
//

/// The part of a `Client` that is encrypted at rest. Sealed as one value by the repository so the schema stays small.
struct ClientSensitiveFields: Codable, Equatable, Sendable {
    var importantNote: String?
    var allergies: [String]
    var sensitivities: [String]
    var preferences: [String]
    var recurringRequests: [String]
    var stopReason: String?

    init(_ client: Client) {
        importantNote = client.importantNote
        allergies = client.allergies
        sensitivities = client.sensitivities
        preferences = client.preferences
        recurringRequests = client.recurringRequests
        stopReason = client.stopReason
    }
}
