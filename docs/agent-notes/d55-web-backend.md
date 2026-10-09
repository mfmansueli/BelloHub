# Agent notes: D55 applied to the web app (`web/`) and the backend (`firebase/functions`)

Branch `d55-web-backend`, from `build/v1` at e74ad8c (7e59797 is an ancestor). Nothing pushed, nothing deployed, no
Firebase command beyond the local emulators. Scope: `web/`, `firebase/`, `scripts/` (unchanged in the end), `docs/`,
`legal/`. `BelloHub/` (iOS), `docs/PROGRESS.md` and `DESIGN.md` are untouched.

D55 (`docs/02-DECISIONS.md`): consents belong to each professional. Bello Hub writes no consent, treatment-agreement,
photo-consent or guardian text for her clients, in the app, on the web page or on the server. The health questionnaire
stays; the "read the text and sign" step is gone. The only legal link on the booking page is Bello Hub's own privacy
policy (as processor), which is not a consent text.

## Commits

1. `155bed0` backend: no consent texts in `intakeForms`, `publishProfile`, `getFormContext`; API.md and schemas.json;
   also fixes a pre-existing `prod-rules` test that counted one `bello-hub` alias after D43 added `dev`.
2. `8853c4b` web: the form is the questions only; payload schema 2; catalogs, legal bundle types, mock, specs, tests.
3. `3a210b9` docs, `legal/README.md`, `legal/STATUS.md`, the client-notice sentence, this file.

## 1. API diff (`firebase/functions/API.md`, `contracts/schemas.json` regenerated)

| Where | Before | After |
|---|---|---|
| `publishProfile.profile.intake` | `{ formVersion, template, consent: Partial<Record<LocaleId, {textVersion, text, guardianText?}>> }` (consent <= 100 KB) | `{ formVersion, template }`. A `consent` field is **`INVALID_ARGUMENT`** (strict object). |
| `getFormContext` response | `{ bookingId, professional, formVersion, template, consent, inboxKey, intakeCompletedWithinMonths }` | same **without `consent`** |
| `SIZE.intakeConsentBytes` | 100 KB cap | removed |
| `IntakeFormDoc` (Firestore `intakeForms/{uid}`) | `consent` map stored | not written. Old documents that still carry `consent` are read fine and the map is never returned (integration test "never returns the consent texts an older health-form document still carries"). The next `publishProfile` replaces the document whole, without it. |
| `submitSealed` | unchanged | unchanged: the envelope never had consent fields on the server side (the server only checks size and shape) |
| Privacy line (API.md top) | "never receives ... a consent signature" | "carries no consent text: consents are the professional's own business; the app only records their status (D55)" |

No cleanup/retention job handled consent texts (they lived only inside `intakeForms`), so nothing to remove there.
Rules: `intakeForms` was already function-only; unchanged.

## 2. Web changes

- `src/routes/form/IntakePage.tsx`: the consent section (server text, "I agree" checkbox, typed signature, guardian
  signature, drawn signature) and the "no consent text" gate are gone. Minor path: the "under 18?" switch, the young
  person's name and the minor questions stay; the helper line reads "A parent or guardian answers for them and comes
  to the visit." (no legal text).
- `src/routes/form/payload.ts`: `IntakeState` is `{ answers, isForMinor, minorName }`; problems are open required
  questions and a missing minor name only; `buildIntakePayload` takes `{ context, localeId, now }`.
- `src/crypto/envelope.ts`: **`IntakePayload` is schema 2**:
  `{ schema: 2, bookingId, localeId, formVersion, answers, isForMinor, minorName?, submittedAt, _pad }`.
  Gone from schema 1: `clientName`, `guardianName`, `consent{textVersion, textLocaleId, acceptedAt, typedSignature}`,
  `signaturePng`.
- Deleted: `src/routes/form/consent.ts` (`signableConsent`), `src/components/SignaturePad.tsx`, the `.sign` CSS,
  `ConsentText`, `WireFormContext.consent`, `FormContext.intake.consent`, `parse.ts: consentOf`.
- Legal bundle: `scripts/build-legal.ts` and `src/legal/index.ts` lose the `consent` and `check` block types; a line
  with a tick box (`☐`) now fails the build ("a consent form has no place in a web notice"). `DOCUMENTS` stays
  `client-notice`, `data-requests`, `privacy-policy` (D49 had already dropped the consent documents from the bundle).
  `Legal.tsx` renders only `h1`, `p`, `ul`.
- Catalogs (14 localizations, gate: 395 keys, 0 problems): removed `cl4.agree`, `cl4.consent`, `cl4.draw`,
  `cl4.drawClear`, `cl4.err.consent`, `cl4.err.sign`, `cl4.noConsent.text`, `cl4.noConsent.title`, `cl4.sign`,
  `cl4.sign.guardian`, `cl4.signPlaceholder`; reworded `cl4.minor.text` and `cl4.sealed` ("Your answers were sealed
  and sent. Only {name} can read them. You will not be asked again for 12 months."). `es-419`/`en-GB` re-derived.
- Mock server: `CONSENT`, the `noConsent` scenario flag and the `maria-noconsent` slug are gone; `getFormContext`
  returns no `consent`.
- Playwright `sealed.spec.ts`: the D49 block is replaced by "no consent on the web (D55)" (no consent text, tick box,
  signature field or canvas, for an adult and for a minor; the page text contains no "I agree"/"consent"); the @core
  test asserts the exact key set of the opened payload; the minor test asserts no `guardianName`/`consent`.
  `e2e-local/booking.spec.ts` asserts the tick box and signature field do not exist before submitting.
- `legal/client-notice/*/2026-10.md` (14 files): the one sentence "It is a separate step with its own consent." now
  says the health form is questions only and any consent is agreed with the professional directly, not on the page.
  `scripts/check-legal-status.sh` passes (headers, placeholders, forbidden claims).

## 3. Docs

`docs/05-DATA-MODEL.md` (HealthForm/ConsentRecord), `docs/06-PRIVACY-SECURITY.md` (classes, payload 3.4, exact
success copy 3.5, consent and minors bullets), `docs/10-WEB-BOOKING.md` (routes table, section 5),
`docs/07-LOCALIZATION.md` section 8 (the three consent documents not produced), `legal/README.md`, `legal/STATUS.md`
(prose only; the generated table keeps the 98 rows because the drafts stay on disk). The sentence used everywhere:
"consents are the professional's own business; the app only records their status".

## 4. Results

- `scripts/test-firebase.sh` (all): lint, typecheck, build, audit ok; **unit 755**, **rules 66**, **use cases 277**,
  **transport 19**, all passed.
- `scripts/test-web.sh full` (E2E_PORT=4112): lint, typecheck, i18n (14 localizations, 395 keys, 0 problems),
  contrast (140/140 pairs), privacy gate, **unit 224 passed (2 skipped)**, production build in budget, **Playwright
  181 passed / 15 skipped** (Chromium, WebKit, low-end), Lighthouse healthcheck passed.
- `scripts/e2e-local.sh` (real functions on the emulators, seeded Maria, the whole story incl. the sealed intake
  without a consent step): **6 passed (17.5 s)**, first run.

## 5. What the iOS agent must do (`BelloHub/`, not touched here)

1. **Publish:** stop sending `intake.consent` in `publishProfile` (the server now answers `INVALID_ARGUMENT` for it;
   an app build that still sends it cannot publish a health form). `PublicProfileInput.intake` is `{formVersion, template}`.
2. **Mailbox import:** accept intake payload **schema 2** (`bookingId, localeId, formVersion, answers, isForMinor,
   minorName?, submittedAt`). Keep decoding schema 1 for envelopes sealed before the web deploy (they carry
   `clientName`, `guardianName`, `consent`, `signaturePng`): import the answers, ignore the rest. The client is the
   booking's client (`bookingId`), not `clientName`.
3. **Vault models:** `HealthForm` loses `signatureImage`/`guardianName` (`docs/05`); `Consent` becomes the D55
   `ConsentRecord` (label, isSigned, date, note?, document?) with no `textVersion`/`localeID`; photo visibility follows
   a signed `photos` record. Keep old stores readable (migration or optional fields).
4. **Bundle:** remove the three consent documents from the app bundle and from `scripts/sync-legal-resources.py`
   (`DOCUMENTS = ["consent-health", "consent-photo", "consent-guardian"]`, and the `.sh` comment), or delete the script
   and `scripts/check-legal-resources.sh` if nothing else is bundled; update `scripts/test.sh` accordingly. Remove the
   files under `BelloHub/Resources/Legal/consent-*-*-2026-10.md` and any screen that renders them (health-form consent
   step, photo consent sheet, guardian consent). `scripts/check-professions.py` has `INTAKE = {..., "consentForm", ...}`:
   drop `consentForm` from the profession presets if it names a consent text.
5. **Form-template publishing:** whatever carried `consent` texts next to the template (`FormTemplates`, D49 code) goes.
6. **Vectors:** `web/test/vectors/inbox-v1.json` and `js-sealed.json` (used by `BelloHubTests/Managers/Vault/InboxVectorsTests.swift`)
   still hold schema-1 intake plaintexts with a `consent` block. They test the crypto, not the schema, so they were left
   as is; if the Swift decoder becomes strict about schema 2, regenerate them (`web/test/vectors/generate/`) in the same change.
7. Strings: the app's own `cl4`-like copy ("your consent is saved with them") if any mirrors `docs/06` 3.5 item 6.

## 6. Not done / open

- `legal/data-requests/*` still says "Your health answers, signature and photos are not on our servers": still true
  (she may keep a photo of a signed paper), left unchanged.
- `docs/14-HUMAN-TASKS.md`, `docs/16-MARKETS.md` and `docs/agent-notes/*` older than this one still mention consent
  texts as history; not rewritten.
- The 42 consent drafts remain in `legal/` and in the `legal/STATUS.md` table (the task said not to delete them).
