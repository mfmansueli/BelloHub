//
//  VaultRepositoryError.swift
//  BelloHub
//

/// What a repository can refuse, in terms the callers can turn into plain-language messages.
enum VaultRepositoryError: Error, Equatable {
    /// A record or incident past its 24-hour lock cannot be edited: add a correction instead.
    case recordLocked
    /// A correction only applies to a locked record; before the lock, edit it directly.
    case recordNotLocked
    case notFound
    /// A stored value could not be read back (a damaged store, or a field this version cannot decode).
    case unreadable
}
