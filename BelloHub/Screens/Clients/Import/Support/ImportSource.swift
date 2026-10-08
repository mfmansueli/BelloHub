//
//  ImportSource.swift
//  BelloHub
//

/// Where the clients come from. Other booking apps are "coming soon" and have no case until they exist.
enum ImportSource: Equatable, Sendable {
    case contacts
    case spreadsheet
}
