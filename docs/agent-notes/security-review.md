# Security review against docs/06-PRIVACY-SECURITY.md (S12, documentation item)

Branch `s8-leftovers`, based on `build/v1` at `4c121a7` (2026-10-10). Reviewer: the S8-leftovers agent. Method: each item
of `docs/06` section 9 (the cross-cutting requirements) and, because section 9 points at them, the controls of sections
3 to 8 and the tests of section 11, checked against the code (file names given), not against the docs. The server half
also has its own review in `docs/agent-notes/backend.md` (`securityReview.test.ts`, 13 emulator tests). Engineering
view, not legal advice (`LEGAL-REVIEW`, O8).

Legend: **OK** = in the code and tested; **PARTIAL** = in the code, with a hole named; **GAP** = not built.

## 1. Section 9: cross-cutting requirements

| # | Requirement | Status | Evidence / gap |
|---|---|---|---|
| 9.1 | Roles: she is the controller, Bello Hub the processor, DPA accepted at sign-up | OK | `legal/` terms + DPA (`terms-dpa`), bundled for 14 localizations and shown in onboarding (`LegalNoticeLibrary`, `check-legal-resources.sh`). Lawyer review is O8 |
| 9.2 | Consent (D55): no consent, treatment-agreement, photo-consent or guardian text anywhere; per-client status records with an optional sealed photo/file | OK | D55 merged (`d55-ios`, `573a50f`): `ConsentRecord` in the vault, document through the photo pipeline (`SystemConsentDocumentReader` reads once, no bookmark); `publishProfile` rejects a `consent` field (API.md 6.2); envelopes of schema 1 still open, their consent block is ignored (`IntakePayload`) |
| 9.3 | Data-subject requests reach her (`datarequest` envelopes, `Cl-7-MyData`) and she fulfils them (`Privacy`, export) | PARTIAL | The web form seals `datarequest` (web `routes/data`), `MailboxService` opens it into `MailboxMessage.dataRequest` (tested: `MailboxServiceTests`), export exists (`DataExportService`, `ExportRecord`). **Gap: no screen lists `MailboxService.messages`**, so a check-in or a data request is opened in memory and never shown; she cannot mark it handled, so it is never acknowledged and expires on the server after 30 days |
| 9.4 | Deletion cascades device + server | PARTIAL | Account: **now real** on this branch (`RemoteAccountDeleter` -> `deleteAccount`, Apple token revoked with a fresh code, D44; device wiped only after the server answered). Client: the server function `deleteClientServerData` exists and is tested, **but the app never calls it** when she deletes a client, so that client's bookings, waitlist rows and portal stay on the server until their own TTL (D30 retention) |
| 9.5 | Retention per profession: a setting with a conservative default, no auto-delete of clinical records | PARTIAL | Privacy screen has the "Retention" row with an explanatory subtitle (`PrivacyContentView`); there is no per-profession setting value and nothing is ever auto-deleted (which is the safe default) |
| 9.6 | Breach plan: one page in `docs/` | GAP | No breach procedure document exists (only mentions in `docs/06` and `docs/07`). Owner task: write it (what to log, who to notify within 72 h under GDPR / "reasonable time" under LGPD, revoke tokens, rotate the inbox key via `updateInboxKey(compromised: true)`) |
| 9.7 | Minors: the form asks whether the visit is for someone under 18 and the name; no guardian text or signature | OK | `IntakePayload.isForMinor/minorName`, `HealthFormSheet`, web form (D55) |

## 2. Controls from sections 3 to 8 that section 9 relies on

| Area | Control | Status | Evidence / gap |
|---|---|---|---|
| 3.1 | HPKE suite exactly as specified; `info` and AAD | OK | `EnvelopeOpener`; cross-implementation vectors both ways (`EnvelopeOpenerTests`, `web/test/unit/crypto.cross-implementation.test.ts`) |
| 3.2 | Inbox key derived from the seed, rotations keep old generations | OK | `KeyManager+InboxKey`, `KeyDerivation` known-answer tests |
| 3.2 | **Public-key integrity**: on every launch and publish the app compares the key the server serves with the one it derives, republishes and alerts on a mismatch | GAP | The app republishes its derived key with every profile publish (`VaultPublishingSource`) and `updateInboxKey` returns the keyring, but nothing reads the served key back and compares, and there is no alert string. A server that swapped the key between publishes would go unnoticed until the next publish overwrote it |
| 3.2 | Key fingerprint on the Privacy screen | GAP (S12 nice-to-have) | Not built |
| 3.5 | Mailbox flow: open, validate, import idempotently by item id, acknowledge, generic alert; undecryptable kept by id and time | OK | `MailboxService` + new `MailboxServiceTests` / `MailboxUndecryptableTests` (this branch): idempotent import, ack through the queue (offline and relaunch replay), unknown key, tampered, misaddressed, unsupported, bad payload, locked keys, no name or answer in the alert |
| 3.5 | Undecryptable alert "A form could not be opened. Ask the client to send it again" | GAP | `MailboxService.undecryptable` is kept and persisted, but no screen shows it (same gap as 9.3) |
| 4.2 | Seed in iCloud Keychain, `AfterFirstUnlock`, synchronizable; keys in memory only, cleared on lock | OK | `KeychainKeyStore`, `KeyManager.lock()`, `AppLockService` |
| 4.2 | Recovery words: Face ID every time, masked, hidden from screenshots/recording, never on the pasteboard | PARTIAL | Face ID gate and masking in `RecoveryKeyContentView` (`.privacySensitive()`), no pasteboard use. **`UIScreen.isCaptured` / screen-recording hiding is not implemented** |
| 4.4 | File protection | PARTIAL | Exports use `ProtectedTemporaryFile` (complete protection, removed after use). The SwiftData store takes the iOS default (`completeUntilFirstUserAuthentication`), which is the choice `docs/06` asks for, but it is **not set explicitly nor recorded with a test** |
| 4.4 | Lock with grace period; app-switcher cover; locked screen shows no data | OK | `AppLockService`/`LockPolicy`, `RootView` `PrivacyCover` when `scenePhase != .active`, `LockedView` |
| 4.4 | Photos never in the camera roll; pasteboard never holds clinical text | OK | `check-privacy.sh` rule 4b; `SystemClipboard` is used only for the booking link (`BookingSettings`, `ShareLink`) |
| 5 | One `SessionService` owns the user; ID token only for functions | OK | `SessionService`, `SessionIDTokenProvider`; `check-privacy.sh` rule 1 keeps Firebase inside `Managers/{Booking,Session,Firebase}` |
| 5 | Phone + SMS sign-in | GAP (decision) | `FirebaseAuthProvider.requestCode/verify` answer `unavailable`; v1 signs in with Apple only (D44). Docs still describe the phone path |
| 6 | Web hardening: CSP, no third-party scripts, no storage in form routes, honest copy | OK | `firebase/firebase.json` headers (CSP, Referrer-Policy, Cache-Control), `check-privacy.sh` rule 5, `web/test/e2e/security.spec.ts` and `sealed.spec.ts` |
| 7 | Rules deny by default; no client writes to server-owned collections | OK | `firestore.rules`, `storage.rules`, 65 rules tests (backend notes) |
| 7 | **App Check enforced** for Firestore, Functions, Storage | GAP (known, H5) | Enforcement is off by decision (D43, D46: the web page sends no App Check token). The iOS app does not send an App Check token either (`URLSessionCallableClient` says so); App Attest is in the entitlements but no provider is wired. Must be done before production, with the web functions exempted |
| 7 | zod on every input, rate limits, generic errors, no PII in logs, secrets in Secret Manager | OK | `firebase/functions/src/contracts`, `lib/rateLimit.ts`, `lib/log.ts`, `check-privacy.sh` rule 6, backend `securityReview.test.ts` |
| 7 | Purchases re-verified on the server; the server is the source of truth for the plan | OK (new) | This branch: `RemoteSubscriptionVerifier` (`ensureAccount.appAccountToken` in the StoreKit purchase, `syncPlan` re-verifies the JWS; `VERIFICATION_FAILED` = no plan). Until H14 installs the Apple root certificates the server answers `NOT_CONFIGURED` and the app keeps StoreKit's on-device verified answer |
| 7 | Registration gate on the server (D42) | GAP | `reserveRegistration(s)` exist on the server, but `ClientRegistrationService` counts locally only; a modified app could register past 10 without a plan. The server gate is only enforced indirectly (booking approval answers `needsSubscription`) |
| 8 | AI on the device only | OK | No network call in `Managers/AI`; `check-privacy.sh` bans analytics SDKs |
| 8 | Push and local notifications: kind + id only, generic text | OK | API.md section 7 (`loc-key` only), `PushEvent`, `MailboxService` alert tested for no name/answer, `NotificationPlannerTests` |
| 8 | Logs: `os.Logger` with privacy; no print | OK | One `Logger` (`SwiftDataClientRecordRepository`, ids and kinds only, `.public` on non-personal values); `check-privacy.sh` rule 3 |

## 3. Section 11: required tests

| # | Test | Status |
|---|---|---|
| 1 | No clinical plaintext on disk (sentinel) | OK: `Repository*ContractTests` sentinel checks |
| 2 | Notification content has no client name | OK: `NotificationPlannerTests` ("No title or body carries a client's name … in any localization"), `MailboxServiceTests.importsIntake` |
| 3 | Vault round-trip, tamper, wrong key, AAD, known-answer | OK: `SecretBoxTests`, `VaultFieldCodecTests`, `KeyDerivationTests`, `VaultVectors` |
| 4 | Recovery phrase checksum and restore | OK: `RecoveryPhraseTests`, `RecoveryKeyServiceTests` (BIP-39 vectors) |
| 5 | Mailbox vectors both ways, idempotent import, undecryptable, wrong key id, tampered AAD | OK: `EnvelopeOpenerTests` + this branch's mailbox suites (the misaddressed test covers a swapped item id in the AAD) |
| 6 | Server rules deny cases; no function logs a body | OK: rules emulator suite, `check-privacy.sh` rule 6 |
| 7 | Web: only envelopes leave with a form; no answer in browser storage | OK: `web/test/e2e/sealed.spec.ts`, `security.spec.ts` |
| 8 | Static checks | OK: `check-privacy.sh` (now also the privacy manifest and required-reason APIs) |

## 4. Gaps, in the order I would fix them

1. **Inbox screens for mailbox messages and undecryptable items** (9.3, 3.5): check-ins and data requests are opened but never shown or acknowledged. Highest product and legal impact (data-subject requests go unanswered). iOS, one screen section in Alerts plus strings.
2. **Client deletion does not reach the server** (9.4): call `deleteClientServerData` from the client-delete flow through the outbound queue.
3. **App Check** (7): wire App Attest in the app, exempt the web functions, then a human turns enforcement on (H5).
4. **Server-side registration gate** (D42): make `ClientRegistrationService` reserve through `reserveRegistration` (it is the server's counter that must decide).
5. **Public-key integrity check and fingerprint** (3.2).
6. **Breach plan page** (9.6), owner and agent together.
7. Screen-capture hiding for the recovery words (4.2) and an explicit, tested file-protection level for the store (4.4).
8. Docs: section 5 still describes phone sign-in; v1 is Apple only (D44).
