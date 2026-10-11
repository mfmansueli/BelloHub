//
//  AccountDeletionConfirmation.swift
//  BelloHub
//

/// How "the server already deleted this account" is kept on the phone between the server's answer and the end of the
/// wipe (`DefaultsKey.accountDeletionConfirmed`): `<userID>|<outcome>`. Ids and an outcome name only. Pure.
enum AccountDeletionConfirmation {
    static func stored(_ outcome: AccountDeletionOutcome, userID: String) -> String {
        "\(userID)|\(name(of: outcome))"
    }

    /// The remembered outcome when `stored` belongs to `userID`; nil for another account or an unreadable value.
    static func outcome(_ stored: String, userID: String) -> AccountDeletionOutcome? {
        let parts = stored.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0] == userID else { return nil }
        switch parts[1] {
        case "deleted": return .deleted
        case "deletedWithoutAppleRevocation": return .deletedWithoutAppleRevocation
        case "deviceOnly": return .deviceOnly
        default: return nil
        }
    }

    private static func name(of outcome: AccountDeletionOutcome) -> String {
        switch outcome {
        case .deleted: "deleted"
        case .deletedWithoutAppleRevocation: "deletedWithoutAppleRevocation"
        case .deviceOnly: "deviceOnly"
        }
    }
}
