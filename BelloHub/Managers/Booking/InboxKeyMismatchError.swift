//
//  InboxKeyMismatchError.swift
//  BelloHub
//

/// The booking page serves an inbox key this iPhone did not derive (see `InboxKeyVerifier`).
struct InboxKeyMismatchError: Error, Equatable {}
