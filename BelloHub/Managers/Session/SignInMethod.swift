//
//  SignInMethod.swift
//  BelloHub
//

/// How the professional proved who she is. Apple is the main way (D44); the phone code is the alternative.
enum SignInMethod: String, Codable, Sendable {
    case apple
    case phone
}
