//
//  VocabularyKind.swift
//  BelloHub
//

/// What a name the professional uses refers to. Both feed the speech recognizer as contextual words (S7), so voice
/// notes spell her services and protocols the way she says them.
enum VocabularyKind: String, PersistedEnum {
    case service
    case protocolName

    static let fallback = VocabularyKind.service
}
