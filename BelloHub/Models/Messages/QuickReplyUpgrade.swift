//
//  QuickReplyUpgrade.swift
//  BelloHub
//

import Foundation

/// Brings the built-in replies she never edited up to the current wording. The replies are copied into her vault the
/// first time she opens them and are hers from then on, so a better default would otherwise never reach her: a stored
/// built-in whose text is still exactly the previous default (in any of the fourteen localizations, since she may have
/// changed her business language since) gets the new default in `localization`. Anything she touched stays as she
/// wrote it. Pure: `now` is a parameter.
enum QuickReplyUpgrade {
    static func upgraded(_ stored: [QuickReply], localization: AppLocalization, now: Date) -> [QuickReply] {
        stored.compactMap { reply in
            guard let builtIn = reply.builtIn else { return nil }
            let previous = AppLocalization.allCases.flatMap { builtIn.previousTexts(in: $0) }
            guard previous.contains(reply.text) else { return nil }
            var upgraded = reply
            upgraded.text = builtIn.text(in: localization)
            upgraded.updatedAt = now
            return upgraded
        }
    }
}
