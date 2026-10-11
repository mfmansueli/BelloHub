# Cross-implementation vectors for the sealed mailbox

The page seals a client's health form in her browser with the professional's public key
(`docs/06-PRIVACY-SECURITY.md` section 3). These vectors prove that what the browser produces can be opened by
someone else's implementation, and the other way round. They are also the file the iPhone (CryptoKit HPKE) reuses.

## Who made what

| File | Made by | Library | Used for |
|---|---|---|---|
| `../inbox-v1.json` | `generate.py` here | **pyhpke 0.6.3** (HPKE) and **cryptography 46** (X25519, OpenSSL) | The independent reference. The page must reproduce every positive envelope byte for byte and open it; every negative case must fail |
| `../rfc9180-vectors.json` | the IETF CFRG (RFC 9180, Appendix A.2), copied from the test suite of pyhpke 0.6.3 | none | A known answer for the exact suite: X25519, HKDF-SHA256, ChaCha20-Poly1305, base mode |
| `../js-sealed.json` | `../generate-js.ts` | **hpke-js** through the page's own `sealPayload` (the `page-*` intakes also through the page's form code, schema 2) | What the browser seals: Python opens it (`verify_js.py`), the iPhone opens it and reads every payload (`BelloHubTests/Managers/Mailbox/EnvelopeOpenerTests.swift`, copied by `scripts/sync-server-contract.sh`) |
| `../swift-sealed.json` | `generate-swift.swift` here | **Apple CryptoKit** `HPKE.Sender`, random ephemeral keys (a fixture, not reproducible) | What the iPhone's library seals: the page's suite and Python open it (`test/unit/crypto.cross-implementation.test.ts`) |

The page itself uses **hpke-js** (`@hpke/core`, `@hpke/dhkem-x25519`, `@hpke/chacha20poly1305`). Nothing in
`generate.py` or `sealed_common.py` shares code with it: the plaintext framing (padding, JSON, AAD) is written again
from the specification.

## The suite and the framing (docs/06 section 3.1 and 3.3)

- HPKE RFC 9180, mode base, KEM DHKEM(X25519, HKDF-SHA256) `0x0020`, KDF HKDF-SHA256 `0x0001`, AEAD ChaCha20-Poly1305 `0x0003`.
- `info` = UTF-8 `bellohub/inbox/v1`.
- AAD = UTF-8 `bellohub/v1|<kind>|<itemId>|<keyId>`.
- `keyId` = base64url(SHA-256(public key)[0..<8]).
- Plaintext = the payload JSON (compact, non-ASCII kept) plus a trailing `"_pad"` of ASCII `0` so the UTF-8 length is a
  multiple of 1 KiB (16 KiB for a check-in with a photo).
- Every binary field is base64url without padding.

## What is in `inbox-v1.json`

- `recipients`: two inbox key pairs (`privateKey` is the raw 32-byte X25519 key, `publicKey`, `keyId`).
- `positive`: nine cases (intake in Portuguese, Arabic for a minor, Hindi with an emoji, a drawn signature, a payload
  whose JSON length is exactly a multiple of 1 KiB, check-in with and without a photo, both data requests). Each has
  the `payload`, the exact `plaintext` that was encrypted, the `aad`, a fixed `itemId`, `ikmE` (the RFC 9180 input key
  material the ephemeral key pair is derived from, so the output is reproducible) and the resulting `envelope`.
- `negative`: twelve envelopes that must not open (flipped ciphertext, tag and encapsulated key, truncated and empty
  ciphertext, changed kind, swapped item id, changed key id, wrong recipient, an `enc` taken from another envelope)
  or must be rejected before opening (version 2, an unknown suite).

## How to use them

Browser (already wired): `npm test` runs `test/unit/crypto.vectors.test.ts` and
`test/unit/crypto.cross-implementation.test.ts`.

iOS (wired): `InboxVectorsTests` opens `inbox-v1.json` and `EnvelopeOpenerTests` opens `js-sealed.json` through the
app's `EnvelopeOpener` and payload readers; `swift-sealed.json` goes the other way. Originally planned: for each positive case, derive the recipient key from `privateKey`, open `envelope` with
`HPKE.Recipient` and the AAD above and compare with `plaintext`; for `js-sealed.json` do the same; to test sealing in
Swift, seal `plaintext` to `publicKey` and check that `generate.py`'s `open_envelope` (or the page's
`test/support/open.ts`) opens it. Every negative case must fail to open.

## Regenerating

```bash
cd web/test/vectors/generate
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python generate.py          # rewrites ../inbox-v1.json (and checks it against RFC 9180)
.venv/bin/python generate.py --check  # fails when the committed file is stale
.venv/bin/python verify_js.py ../js-sealed.json    # opens what the page sealed
# after any change to js-sealed.json (from the repository root):
xcrun swift web/test/vectors/generate/generate-swift.swift web/test/vectors/js-sealed.json web/test/vectors/swift-sealed.json
scripts/sync-server-contract.sh                       # copies js-sealed.json into the iOS test bundle
```
`scripts/test-web.sh` makes its venv at `web/.venv`; the unit tests use it (or one here) to run `verify_js.py`.

`generate.py` refuses to write a file unless pyhpke reproduces the RFC 9180 vector, round-trips every positive case
and fails every negative case. Do not hand-edit the JSON files. A change to the suite, the AAD, the padding or the
payload fields is a protocol change: it needs a recorded decision (`docs/06` section 3.1) and a new vector file
version, never a silent regeneration.
