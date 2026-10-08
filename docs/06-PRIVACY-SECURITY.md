# 06 · Privacy and security

This is the most important document after the product rules. Privacy here is **architecture, not policy text**: the server is built so that it cannot read clinical data. Implement exactly what this file says; where it says "verify", write the result in `docs/PROGRESS.md`.

*Legal notes in §9 are engineering guidance, not legal advice. Everything marked `LEGAL-REVIEW` needs a data-protection lawyer before real professionals use the product (O8).*

---

## 1. Data classes

| Class | Examples | Where it may live | Rule |
|---|---|---|---|
| **S · Sensitive** | health answers, consent signature, treatment notes, allergies, sensitivities, incident details, photos, audio, transcripts, client habits, private notes | iPhone vault + her iCloud (encrypted by the app, D26). In transit from a client: **sealed envelope** only | Never readable by any server, log, analytics, notification, email, WhatsApp text, crash report or third party |
| **O · Operational** | client name, phone, optional email, service, time, status, policy values, availability, busy blocks, push tokens | Firestore/Functions (D3), iPhone | Minimum necessary; deleted per D30; no PII in logs |
| **P · Public** | business name, bio, photo, city, public credentials, services the professional chose to publish, rules text, inbox **public** key | Firestore `publicProfiles`, the web page | Only what she publishes |

If you are unsure which class a field is, treat it as S.

## 2. What each party can see

| | Professional | Client | Bello servers | Apple (iCloud) | Third parties |
|---|---|---|---|---|---|
| Her records, photos, health, notes | ✔ | only what she shares (portal) | ✘ never | encrypted blobs only (keys not held by Apple's side of the app layer) | ✘ |
| Client's health form (while in transit) | after import | ✔ (her own input) | opaque envelope, size and timing | ✘ | ✘ |
| Booking facts (name, phone, time, service) | ✔ | ✔ own | ✔ (operational need) | ✘ | email/SMS provider sees the code/message content they deliver (no clinical content) |
| Voice and transcript | ✔ | ✘ | ✘ | ✘ (audio discarded) | ✘ (on-device AI) |

## 3. The sealed mailbox (client → professional)

Goal: a client fills in a health form in her browser; **only the professional's iPhone** can read it; the server stores an opaque blob for the shortest possible time.

### 3.1 Cryptographic suite (do not change without a recorded decision)

- **HPKE** (RFC 9180), mode **base**, KEM **DHKEM(X25519, HKDF-SHA256)** (id `0x0020`), KDF **HKDF-SHA256** (`0x0001`), AEAD **ChaCha20-Poly1305** (`0x0003`).
- iPhone: `CryptoKit` `HPKE` with `HPKE.Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .chaChaPoly)`; the iPhone uses `HPKE.Recipient` to open (and `HPKE.Sender` in tests).
- Browser: **`hpke-js`** (`@hpke/core` + `@hpke/dhkem-x25519` + `@hpke/chacha20poly1305`), exact versions pinned, **bundled into our own JS** (no CDN at runtime), covered by SRI/CSP. No custom crypto anywhere.
- `info` = UTF-8 `bellohub/inbox/v1`.
- AAD = UTF-8 `bellohub/v1|<kind>|<itemId>|<keyId>`. This binds the ciphertext to its kind, its item id and the key, so the server cannot swap or replay envelopes.
- Plaintext is padded to a multiple of 1 KiB (a `_pad` field in the JSON) for `intake`, and to 16 KiB for `checkin` with a photo, to blur sizes.
- Post-quantum: if CryptoKit and `hpke-js` both ship a hybrid KEM (e.g. X-Wing) when you reach S12, record it as a proposal in `PROGRESS.md`; do not change the suite unilaterally.

### 3.2 Keys

- The professional has an **inbox key pair** (X25519) derived from her recovery seed (§4). Public key: `inboxKey = { keyId, alg: "hpke-v1", pub: <base64url 32 bytes> }` where `keyId = base64url(SHA-256(pub)[0..<8])`.
- She publishes it to `publicProfiles/{slug}.inboxKey` and to `accounts/{uid}.inboxKeyring` (list of current and previous key ids). On rotation, old private keys (derived by generation, §4) stay available to decrypt items still in the mailbox.
- **Public-key integrity.** The app checks on **every launch and every publish** that the key served by the server equals the key it derived; if not, it republishes and shows an alert ("Your booking form key was changed. If you did not do this, contact support"). Writes to `inboxKey` are allowed only by the authenticated owner (rules) and are logged without values. The Privacy screen shows a short **fingerprint** of the key (first 8 bytes in 4 groups) so she can compare it with what the page reports (Stage S12 nice-to-have; the key id is already in the page footer).

### 3.3 Envelope (what the server stores)

```json
{
  "v": 1,
  "suite": "hpke-x25519-hkdf-sha256-chacha20poly1305",
  "keyId": "Qx9fT2mA7Hk",
  "kind": "intake",
  "itemId": "3f2a…uuidv4 generated in the browser",
  "enc": "<base64url encapsulated key, 32 bytes>",
  "ct": "<base64url ciphertext || 16-byte tag>"
}
```

Server-side metadata next to it: `ownerUid`, `bookingId`, `createdAt`, `expiresAt`, `sizeBytes`, `kind`. Nothing else.

### 3.4 Payload kinds (UTF-8 JSON before sealing)

- `intake` (≤ 256 KB): `{schema:1, bookingId, clientName, localeId, formVersion, answers:{<questionKey>:<value>}, isForMinor, minorName?, guardianName?, consent:{textVersion, textLocaleId, acceptedAt, typedSignature}, signaturePng?:<base64, ≤ 64 KB>, submittedAt, _pad}`
- `checkin` (≤ 3 MB, stored in Cloud Storage when > 200 KB): `{schema:1, bookingId, feeling:"good"|"okay"|"irritated"|"reaction", note?, photoJpeg?:<base64 ≤ 1.5 MB>, submittedAt, _pad}`
- `datarequest` (≤ 8 KB): `{schema:1, request:"copy"|"delete", name, phone, note?, submittedAt, _pad}`

Question keys and answer value types are defined by the professional's `FormTemplates` version; the web app receives the template (questions, localized labels) from `publicProfiles` and the app validates answers on import against the same version.

### 3.5 Flow

1. **Browser:** loads the page (client has the personal link `…/m/{token}`), fetches the template and `inboxKey`, collects answers in memory only (never `localStorage`, `sessionStorage`, URL, or analytics), builds the payload, seals it, submits `{token, envelope}` to the function `submitSealed`.
2. **Function:** verifies the App Check token, the manage token (hash lookup), the booking state, kind and size limits, and a rate limit (5 per booking per hour, 20 per IP per hour); writes the envelope to `inbox/{uid}/items/{itemId}` (or Storage + metadata for large ones) with `expiresAt = now + 30 days`; sends a **silent** FCM push (`content-available`, no text). Returns `{ok:true}`. Logs: ids and sizes only.
3. **iPhone:** `MailboxService.sync()` runs on push, on foreground, and on pull-to-refresh in `Notifications`. For each item: download → find the private key by `keyId` → open → validate the schema → `ClientRecordRepository.importIntake(_, itemID:)` in one transaction (idempotent by `itemId`) → `acknowledgeMailboxItem(itemID)`. Then it raises a normal alert "A client sent her health form" (no name on the lock screen).
4. **Function:** on acknowledge, deletes the item (and Storage object) immediately; a scheduled job deletes anything past `expiresAt`.
5. **Failure handling:** decrypt or schema failure → keep a local `undecryptable` record (id and time only), alert "A form could not be opened. Ask the client to send it again", leave the server item until TTL. App crash between import and acknowledge → next sync sees the id already imported, skips the import and acknowledges.
6. **Client feedback:** after submit, the page shows exactly: "Your answers were sealed and sent. Only Maria can read them, and your consent is saved with them. You will not be asked again for 12 months." (localized, with the professional's first name).

### 3.6 What the server learns

That a given booking has a sealed form, its size class and time. State this honestly in the privacy policy (`LEGAL-REVIEW`). It does not learn any answer.

## 4. The vault and the recovery key

### 4.1 Key hierarchy (D22, D26)

```
entropy E (128 bits, SecRandomCopyBytes)  ──▶  12-word BIP-39 phrase (English wordlist, 2048 words, checksum)
   │
   └─ masterKey = HKDF-SHA256(ikm: E, salt: "bellohub.v1", info: "master", L=32)
        ├─ vaultKey   = HKDF-SHA256(ikm: masterKey, salt: ∅, info: "bellohub/vault/aes256gcm/v1", L=32)   // field and photo encryption
        └─ inboxSeed_g = HKDF-SHA256(ikm: masterKey, salt: ∅, info: "bellohub/inbox/x25519/v1/g<g>", L=32) // g = 1, 2, … generation
              └─ X25519 private key (rawRepresentation = inboxSeed_g) → public key → keyId
```

- Do **not** implement BIP-39 as a wallet. Use only the mnemonic encode/decode with checksum (SHA-256, first 4 bits) so typos are detected. Fetch the official English list with `scripts/fetch-wordlist.sh`, assert exactly 2048 unique words, commit the file (`Managers/Vault/Bip39Wordlist.swift` or a resource) and test the first and last words and the checksum rule with published vectors.
- Add **known-answer tests**: fixed `E` → expected `masterKey`, `vaultKey`, `inboxSeed_1`, public key, `keyId` (hard-code the values after the first run and never change them without a migration).
- Everything derived is recomputable from the 12 words. Nothing else is needed to recover.

### 4.2 Storage on the iPhone

- On first launch (before the first sensitive write) generate `E` and store it in the **iCloud Keychain**: `kSecClassGenericPassword`, service `app.bellohub.keys`, account `seed.v1`, `kSecAttrSynchronizable = true`, `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlock`. Cache derived keys in memory only; clear them when the app locks.
- Showing the recovery phrase requires **Face ID or the device passcode** (`LAPolicy.deviceOwnerAuthentication`) every time. The words are rendered masked until she taps "Show with Face ID" (prototype `7.9`), excluded from screenshots/screen recording where the system allows (`UIScreen.isCaptured` hides them), and never placed on the pasteboard.
- "Save to Files" exports a small text file; "Print" uses `UIPrintInteractionController`. Both are her choice; warn that anyone with the words can read her records.
- `RecoveryKey` state (`saved: Bool`, date) is a local, non-secret setting read by `Privacy` (`keySub`: "Saved on Oct 8" / "Not saved yet. Save it before you need it").
- Prompt once, non-blocking, after the **first sensitive record is saved**, and keep a persistent hint in `Privacy` until saved.

### 4.3 Loss and restore scenarios

| Scenario | What happens |
|---|---|
| New iPhone, same Apple ID, iCloud Keychain on | Seed arrives with Keychain; records arrive with CloudKit; works without the 12 words. |
| New iPhone, iCloud Keychain **off** or Apple ID changed | Records are encrypted and unreadable until she types the 12 words in the restore screen; then everything decrypts. Without the words the data is **unrecoverable by design**. |
| Lost phone, recovery key saved | Restore as above. Pending envelopes still decrypt (inbox key regenerated from the same seed). |
| Forgot to save the key and lost all access | Unrecoverable. Bello cannot help (this must be said plainly in `RecoveryKey` and the help text). |
| She rotates the inbox key (v1: model and tests only, no UI) | New generation `g+1` becomes current; old generations stay for pending items. |
| Advanced Data Protection on/off | Works either way; recommend ADP in `Privacy` help text as optional. |

### 4.4 At-rest protections on the device

- Store files with `NSFileProtectionComplete` (`completeUntilFirstUserAuthentication` for the SwiftData store, which must stay available to background sync; verify and record the choice).
- Face ID/passcode lock with a configurable grace period; content hidden in the app switcher; "Locked" screen shows no client data.
- Temp files (PDF exports, share-sheet items) in a protected temp directory, deleted after use.
- Photos never in the camera roll. The pasteboard is never used for clinical text; for sharing, use `ShareLink`/share sheet with a file.

## 5. Authentication and sessions

- **Professional:** phone number + SMS code through Firebase Auth (behind `AuthProvider`); the Firebase ID token is used only for the booking/mailbox functions. Face ID unlock is local. Sign-out clears the session, queues, caches and **keeps the vault** (it is her data; deleting the account is a separate, confirmed action).
- **Client:** no account. Identity = possession of the **personal link** `…/m/{token}` (128-bit random, stored hashed on the server, valid until the visit ends + 7 days) plus, for "Find my appointment", a code sent to the phone she booked with. Tokens are never logged. Pages set `Referrer-Policy: no-referrer`, `Cache-Control: no-store`, `X-Robots-Tag: noindex`.
- **Portal** tokens (`Cl-2-Portal`) are per client and professional, revocable by the professional, expire after 180 days of inactivity, and expose only what she chose to publish.

## 6. Web hardening and honesty about E2EE

Controls: strict **CSP** (`default-src 'none'`; `script-src 'self'` with hashes; `connect-src` only our function origins and Firebase endpoints; `img-src 'self' data:`; `frame-ancestors 'none'`; `base-uri 'none'`; `form-action 'self'`), **SRI** on any external-looking asset (there are none; fonts and scripts are self-hosted), `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Permissions-Policy` empty, **no third-party scripts and no analytics on any page that can contain a form**, dependencies pinned with lockfile and `npm audit` in CI, build is reproducible and the bundle hash is published in `/.well-known/bellohub-build.txt`.

The honest limit: **the server serves the code that encrypts.** A compromised or malicious server could serve code that exfiltrates answers before sealing. Mitigations: the controls above, the key-integrity check in the app (§3.2), published bundle hashes, minimal dependencies, and a documented path to a signed-bundle or browser-extension verifier later. **Marketing and legal copy may say "sealed in your browser, only <Name> can read it" and "Bello cannot read it". It must not say "impossible to intercept" or "unhackable".**

## 7. Server hardening

- Firestore rules deny by default; owner-scoped reads; **no client writes** to `bookings`, `inbox`, `portal`, `rescheduleRequests`, `waitlist` (Functions only). `publicProfiles` writes only by the owner and validated by shape.
- **App Check** enforced (App Attest on iOS; reCAPTCHA Enterprise on web) for Firestore, Functions and Storage.
- Functions: schema validation (e.g. `zod`) on every input, per-token and per-IP rate limits, generic errors, **no PII or payloads in logs**, secrets in Secret Manager, minimum IAM roles, one service account per concern.
- Backups/PITR contain operational PII: keep PITR short, document it in the privacy policy, and make sure delete cascades also remove it within the stated window.
- Emails: transactional provider with a DPA; content is booking facts only (what, when, link, rules). No clinical content, ever.

## 8. AI, notifications, messages

- **AI** is on-device (D23, `12-AI-AND-VOICE.md`). No transcript or text leaves the phone. There is no cloud AI in v1; the interface that could host it is disabled by a flag and any future use must ask the professional first and exclude identifying data.
- **Push and local notifications:** generic text and ids only ("New booking", "A client sent a form"). Lock-screen names are never shown (also not when she turns the privacy toggle off; the toggle only controls whether names show **inside** the app's alerts list).
- **WhatsApp/SMS/email to clients:** booking facts only (service, date, time, link, rules). Never allergies, results, aftercare details or photos. Aftercare is delivered through the portal link, which opens a page the professional chose to publish.
- **Logs/crashes:** `os.Logger` with `.private`; no analytics SDK; MetricKit only.

## 9. Regions, roles and laws (engineering view, `LEGAL-REVIEW`)

**Roles.** The professional is the **controller** (Brazil: *controlador*; EU: *responsável pelo tratamento / responsable del tratamiento*) of her clients' data. Bello Hub is a **processor/operator** for the operational data it hosts, with a Data Processing Agreement accepted in the app at sign-up. The vault is the professional's own storage; Bello does not have the keys.

| Market | Framework to design for | Notes for the build |
|---|---|---|
| Brazil | **LGPD** (Law 13.709/2018); health data is *dado pessoal sensível* | Explicit consent for sensitive data, purposes, data-subject rights (access, correction, deletion, portability) served by `Privacy`/`ExportAll`/`Cl-7-MyData`; international-transfer safeguards for Firebase; incident notification procedure. Provide a Portuguese privacy notice and consent text. |
| Portugal | **GDPR/RGPD** + **Lei 58/2019** | Art. 9 special category (health): explicit consent or health-care basis; DPA with processors; transfers outside the EEA need safeguards (Firebase region EU, D29). |
| Spain | **RGPD** + **LOPDGDD** | As above. Note stricter expectations for minors (guardian consent) and clinical record retention for healthcare professions (verify per profession). |
| Mexico | **LFPDPPP** (federal private-sector law) | Privacy notice (*aviso de privacidad*) integral/simplified/short; consent for sensitive data must be express; ARCO rights (access, rectification, cancellation, opposition). |
| United States | State laws: **CCPA/CPRA** (California), **Washington My Health My Data Act**, others (Texas, Virginia…); HIPAA generally **does not** apply to a non-covered independent beauty professional, but some aesthetic-health roles may be covered entities | Consumer-health-data notice and consent flows, deletion on request, no sale or sharing of health data. Let the professional state if she is a HIPAA covered entity (setting in `Privacy` → help text only, no feature in v1). |

Cross-cutting engineering requirements that follow:
- **Consent** is recorded with `textVersion`, locale, timestamp and signature (typed or drawn), per purpose (treatment, photos).
- **Data-subject requests** reach the professional through `datarequest` envelopes and `Cl-7-MyData`; she fulfills them from `Privacy`/`ExportRecord`/`ExportAll`; deletion cascades (device + server).
- **Retention** per profession is a setting with a conservative default and a note that legal minimums may apply (do not auto-delete clinical records by default; warn instead).
- **Breach plan:** a documented one-page procedure in `docs/` for the owners (what to log, who to notify, how to revoke tokens and rotate keys).
- **Minors:** guardian flow (D17); texts provisional.

## 10. Threat model (summary)

| Threat | Mitigation |
|---|---|
| Curious or compromised Bello server/admin reads health data | It is never there in readable form (D21, D26). |
| Network attacker | TLS everywhere, HSTS, HPKE sealing on top of TLS. |
| Malicious server swaps the professional's public key | App verifies the published key on launch/publish; rules restrict who writes it; fingerprint; honest copy (§6). |
| Replay or swap of envelopes | AAD binds kind, item id, key id; item ids are single-use. |
| Attacker with the client's link | Link grants only her own booking; no health data is ever returned by the server; token expiry; rate limits; "Find my appointment" needs a code. |
| Stolen iPhone | Data protection + Face ID/passcode lock + app lock + blur; Find My; vault keys cleared on lock. |
| iCloud account takeover | Records are encrypted with a vault key that is not in CloudKit; Keychain access also needs the attacker to compromise iCloud Keychain. Recommend ADP. |
| Lost phone with no recovery key | Unrecoverable by design; warn clearly. |
| Malicious browser extension or compromised client device | Out of scope; limit exposure (answers only in memory). |
| Spam bookings | App Check, verification code, rate limits, approval mode, no-show protection. |
| Insider misuse of logs | No PII in logs. |

## 11. Privacy and security tests (must exist)

1. **No clinical plaintext on disk**: a test writes a sentinel string through each sensitive field and asserts it is absent from the SQLite/store files and the external-storage directory.
2. **Notification content**: scheduler tests assert generic titles/bodies contain no client name.
3. **Vault**: round-trip, tamper (flip a byte → open fails), wrong key fails, AAD mismatch fails; known-answer derivation vectors.
4. **Recovery**: phrase round-trip with checksum; one wrong word fails; restore on a fresh store decrypts earlier records.
5. **Mailbox**: RFC 9180 vectors for the suite pass in Swift and in the browser; **cross-implementation vectors** (Swift seals → JS opens, JS seals → Swift opens) are committed in `web/test/vectors/` and `BelloHubTests/Vectors/`; idempotent import; undecryptable item path; wrong `keyId`; tampered AAD.
6. **Server rules** (emulator): every deny case in §7; envelope readable only by its owner; no function logs a body.
7. **Web**: a Playwright test intercepts every request while a health form is submitted and asserts the only request carrying form content contains an envelope, never an answer string; another asserts no `localStorage`/`sessionStorage`/cookie holds an answer.
8. **Static checks**: a script fails if `print(` or logging of interpolated client fields appears outside DEBUG tools, if any Firebase module is imported outside `Managers/Booking`, or if SwiftData/CloudKit is imported outside `Managers/Persistence`.

## 12. Copy rules

Allowed: "Your records stay on your iPhone and in your iCloud." "Bello Hub can't read your clients' health forms." "Sealed in your browser, only <Name> can read it." Forbidden: any claim of absolute security, any claim that Apple or the professional's iCloud provider cannot ever access data (say "encrypted"), any claim of legal compliance ("GDPR compliant") before review (O8). All privacy-relevant strings are in the glossary and reviewed in S11.
