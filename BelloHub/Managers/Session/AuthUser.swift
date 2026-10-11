//
//  AuthUser.swift
//  BelloHub
//

/// The signed-in professional as the app knows her: an opaque id, how she signed in and, when the method gives one,
/// the phone or the name. A professional who signed in with Apple has no phone number (D44), so it is optional.
struct AuthUser: Equatable, Hashable, Codable, Sendable {
    let id: String
    let method: SignInMethod
    /// International format, plus sign and digits only. Only a phone sign-in has one.
    let phoneE164: String?
    /// The name Apple gave on the first sign-in, to prefill the About-you step. Apple sends it once, so it is kept
    /// with the user until the setup finishes; she can change it there.
    let displayName: String?

    init(id: String, method: SignInMethod = .phone, phoneE164: String? = nil, displayName: String? = nil) {
        self.id = id
        self.method = method
        self.phoneE164 = phoneE164
        self.displayName = displayName
    }

    /// Users saved before Apple sign-in existed have no `method`: they signed in with the phone.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        method = try container.decodeIfPresent(SignInMethod.self, forKey: .method) ?? .phone
        phoneE164 = try container.decodeIfPresent(String.self, forKey: .phoneE164)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
    }
}
