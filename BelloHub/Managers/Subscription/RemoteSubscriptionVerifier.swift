//
//  RemoteSubscriptionVerifier.swift
//  BelloHub
//

import Foundation

/// The server as the source of truth for her plan (D33, D42; firebase/functions/API.md sections 6.1 and 6.7):
/// - before a purchase, `ensureAccount` gives the account's `appAccountToken`, which StoreKit puts in the
///   transaction, so `syncPlan` and the App Store Server Notifications can tie it to her account;
/// - after every store change, `syncPlan` re-verifies the signed transaction (Apple's JWS chain, bundle, products,
///   account token) and answers the plan the server now holds in `accounts/{uid}.plan`. That answer is what the app
///   shows; the registration gate on the server reads the same field.
///
/// An explicit "this transaction is not hers" (`VERIFICATION_FAILED`) means no plan. Every other failure (offline, the
/// App Store settings not installed yet, H14) is thrown, and `SubscriptionService` keeps the store's own signed answer.
struct RemoteSubscriptionVerifier: SubscriptionVerifying {
    private let client: any CallableClient
    private let accounts: any BookingRepository
    private let profile: @Sendable () async -> ProfessionalProfile?

    /// `accounts` answers `ensureAccount` (the same server the booking page uses); `profile` gives the region and
    /// language the account is created with when it does not exist yet.
    init(
        client: any CallableClient,
        accounts: any BookingRepository,
        profile: @escaping @Sendable () async -> ProfessionalProfile?
    ) {
        self.client = client
        self.accounts = accounts
        self.profile = profile
    }

    func purchaseToken() async throws -> UUID? {
        guard let profile = await profile() else { throw SubscriptionError.accountUnavailable }
        let account: AccountInfo
        do {
            account = try await accounts.ensureAccount(countryCode: profile.regionCode, locale: profile.appLocaleID)
        } catch {
            throw SubscriptionError.accountUnavailable
        }
        guard let token = UUID(uuidString: account.appAccountToken) else {
            throw SubscriptionError.accountUnavailable
        }
        return token
    }

    func verify(_ state: SubscriptionState, signedTransaction: String?) async throws -> SubscriptionState {
        // No entitlement on the store: nothing to prove, and nothing to unlock.
        guard let signedTransaction, !signedTransaction.isEmpty else { return state }
        do {
            let answer: Answer = try await client.call("syncPlan", Body(signedTransaction: signedTransaction))
            return Self.state(server: answer.plan, store: state)
        } catch ServerError.unexpected(code: "VERIFICATION_FAILED") {
            return .none
        }
    }

    /// The server's plan in the app's terms. The period and the renewal flag are the store's (the server does not
    /// keep them); the dates and whether there is a plan at all are the server's.
    static func state(server plan: Plan, store: SubscriptionState) -> SubscriptionState {
        let period = store.period ?? .monthly
        switch plan.state {
        case "active":
            let willRenew = if case .active(_, _, let renews) = store { renews } else { true }
            return .active(period: period, expiresAt: plan.expiresAt, willRenew: willRenew)
        case "grace":
            return .inGracePeriod(period: period, expiresAt: plan.expiresAt)
        default:
            // "none", "expired", "revoked" (a refund wins over everything).
            return .none
        }
    }

    // MARK: - Wire shapes

    private struct Body: Encodable {
        let signedTransaction: String
    }

    struct Plan: Decodable, Equatable {
        let state: String
        let expiresAt: Date?
    }

    private struct Answer: Decodable {
        let plan: Plan
    }
}
