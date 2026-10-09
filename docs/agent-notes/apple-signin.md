# Sign in with Apple (D44)

Branch `apple-signin` (from `build/v1` at 31ba797).

## What was built

- Entitlement `com.apple.developer.applesignin = [Default]` is back in `BelloHub/SupportFiles/BelloHub.entitlements`.
- `AuthUser` now has `method: SignInMethod` (`.apple` / `.phone`), optional `phoneE164` and optional `displayName`.
  Users saved before this change decode as `.phone` (custom `init(from:)`). The `LocalDevAuthProvider` user in
  UserDefaults keeps working. Readers fixed: `UITestSeeding`, `FakeAuthProvider`, `RootGateTests`.
- `Managers/Session/`: `SignInMethod`, `AppleCredential` (framework-free), `AppleNonce` (raw nonce via
  `SecRandomCopyBytes` with rejection sampling, SHA-256 hex via CryptoKit), `AppleCredentialProviding` (protocol),
  `SystemAppleCredentialProvider` (over `AuthenticationServices`: scopes full name + email, hashed nonce, reads the
  credential), `AppleSignInErrorMapper` (cancel -> `AuthError.cancelled`), `FirebaseAuthProvider` (Release),
  `AppleCredential+DevStub` (DEBUG). `AuthProvider` gained `signInWithApple(_:)`; `SessionService.signInWithApple`.
  `AuthError` gained `.cancelled` and `.appleFailed`.
- `FirebaseAuth` was already linked, so `FirebaseAuthProvider` does the real exchange
  (`OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)` then `Auth.auth().signIn(with:)`). Release now uses
  it instead of `UnconfiguredAuthProvider` (which stays, unused by the factory). Its phone path answers `unavailable`
  until S8. **Compiled, not verified against the live project** (needs the Apple provider enabled in the Firebase
  console, the Services ID / key configured, and a real Apple sheet).
- UI: `Screens/Shared/AppleSignIn/` (`AppleSignInViewModel`, `AppleSignInSection`). The native `SignInWithAppleButton`
  (`.continue`, black on light, white on dark, height 56) is the primary action on Welcome, with "Use phone number
  instead" (`welcome.phoneButton`) as the secondary. The SignIn phone step shows the same button under the phone form
  (separated by "or"). Identifier `signIn.appleButton` on both screens (they never show at the same time); errors
  under it as `signIn.appleButton.error`. Cancel shows nothing; other failures show an honest message; network,
  unavailable and too-many map to the existing messages.
- The Apple name (only sent on the first authorization) is kept in `AuthUser.displayName` and prefills the About-you
  name field through `SetupView(suggestedName:)`; she can edit it.
- UI-test hook: in a `-uiTesting` launch a transparent button over the real Apple button signs the fixed dev Apple user
  (`AppleCredential.devStub`, name "Helena Duarte", distinct from the "Maria Silva" placeholder of the name field) in through `LocalDevAuthProvider`, with no UI. The real button stays
  drawn underneath so the audits still measure it.

## Files

New: the Session files above; `Screens/Shared/AppleSignIn/*`; `Config/Locale/strings/s6x-apple-signin.json`;
tests `AppleNonceTests`, `AuthUserTests`, `AppleCredentialProviderTests`, `AppleSignInViewModelTests`,
`FakeAppleCredentialProvider`, additions to `SessionServiceTests`; UI `AppleSignInUITests`.
Changed: `WelcomeView` (new init: `session`, `onSignedIn`, `onUsePhone`), `SignInView`, `SetupView`, `RootView`,
`SessionService`, `LocalDevAuthProvider`, `UnconfiguredAuthProvider`, `AuthProviderFactory`, UI test helpers
(`createAccount` now taps `welcome.phoneButton`), `OnboardingAuditUITests`, `LaunchUITests`, `LockUITests`.

## Decisions and assumptions

- ASSUMPTION-A1: the Welcome "Get started" / "Sign in" pair is replaced by Apple (primary) + phone (secondary), since
  Apple creates and opens a workspace alike. The old keys `onb.welcome.getStarted`, `onb.welcome.haveAccount`,
  `onb.welcome.signIn` are now unused by Welcome (`onb.welcome.haveAccount`/`signIn` are not used anywhere else; the
  coordinator may drop them from the catalog). The SignIn screen keeps its own create/existing switch link.
- ASSUMPTION-A2: deviation from "SignIn shows Apple as primary": the SignIn screen is the phone form (reached through
  "Use phone number instead"), so its primary stays "Send code" and the Apple button sits below the form. One native
  Apple button per screen either way.
- ASSUMPTION-A3: `displayName` is stored with the user (UserDefaults dev user in DEBUG; Firebase `displayName` in
  Release, which Firebase fills from the `fullName` passed with the credential). It is not a clinical field.
- No Apple tokens or authorization codes are stored (the code is carried in `AppleCredential` only for the sign-in call).
- Pre-existing: `scripts/test.sh` stops at `scripts/check-privacy.sh` on `web/src/routes/form/IntakePage.tsx:4` (a
  comment that contains the word `localStorage`). Not touched here (web agent's area). The test plans were run through
  `xcodebuild` with the same wrapper (`run_xcodebuild`) minus that gate.

## What S10 (account deletion) must do

Apple requires the token to be revoked when the account is deleted (App Store guideline 5.1.1(v)).
- The client must obtain a **fresh** authorization code at deletion time: run `ASAuthorizationAppleIDProvider` again
  (re-authenticate, same nonce handling through `AppleCredentialProviding`) and send `authorizationCode` to the
  deletion callable. A code saved from sign-in is single-use and expires in minutes, so nothing is stored now.
- Backend `deleteAccount` callable: add a parameter `appleAuthorizationCode: string | null` (null for phone owners).
  The server exchanges it at `https://appleid.apple.com/auth/token` (client secret = JWT signed with the Sign in with
  Apple key) for a refresh token, then POSTs `https://appleid.apple.com/auth/revoke`. Firebase Admin also offers
  `revokeAppleToken` through the client SDK: `Auth.auth().revokeToken(withAuthorizationCode:)` (iOS SDK 10.24+) does the
  same from the device and may replace the server step; decide with the backend agent. Then delete the Firebase user.
- The Apple key id, team id and services id are server secrets (Secret Manager); never in the app.
- `AppleCredential.authorizationCode` already carries the code and `FirebaseAuthProvider` is the only place that may call
  `revokeToken`, if the device-side route is chosen.

## DESIGN.md additions (for the coordinator)

- Welcome (1.1): primary action is the native Sign in with Apple button (`signIn.appleButton`); secondary "Use phone
  number instead" (`welcome.phoneButton`); no Get started / Sign in pair.
- SignIn (1.2) phone step: "or" + native Apple button under the form; error under it (`signIn.appleButton.error`).
- Component: `AppleSignInSection` (Screens/Shared/AppleSignIn): native button, black on light / white on dark, 56 pt,
  system label and localization, cancel is silent.
- Tokens: none added. States: working (button disabled), failed (coral footnote), cancelled (nothing).
- About-you: name prefilled from Apple when available.
- Strings: `onb.apple.usePhone`, `onb.apple.or`, `onb.apple.error.failed`.

## Results

- Fast (unit): passed (1378 tests in 170 suites on the first full run; the Apple tests add about 20).
- UISmoke: 21 UI tests; the new `AppleSignInUITests` (3) passed after fixing a test that compared against the
  "Maria Silva" placeholder; every other flow passed.
- `OnboardingAuditUITests` in `en,ar` (`TEST_RUNNER_AUDIT_LOCALES=en,ar`), default size and AX5, plus the Locked screen:
  all three tests passed (welcome with the Apple button, sign-in phone step with the Apple button, code, setup).
- Zero warnings (SwiftLint included) on simulator Debug, device Debug, simulator Release and the test targets.
- `scripts/check-strings.sh` passes (1036 keys, three new in 14 localizations).
- Provisioning: `xcodebuild -allowProvisioningUpdates -destination generic/platform=iOS` signed Debug build succeeded
  with the entitlement in place.
- `scripts/test.sh` and `scripts/check-warnings.sh` stop at `scripts/check-privacy.sh` on a pre-existing line in
  `web/src/routes/form/IntakePage.tsx` (not from this work). The same steps were run through `run_xcodebuild` without
  that one gate.

## Not done

- Live Firebase exchange not verified (see above); Apple provider must be enabled in the Firebase console.
- The Apple private-relay e-mail is received but unused (no e-mail is stored for the owner).
