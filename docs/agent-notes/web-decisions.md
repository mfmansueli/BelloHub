# Agent notes: owner decisions D45 to D52 applied to the client web app (`web/`)

Branch `web-decisions`, from `build/v1` at 31ba797. Commits on top (nothing pushed; only `web/`, this file and
`scripts/test-web.sh` are in scope, `firebase/`, `docs/PROGRESS.md` and `DESIGN.md` untouched):

1. D45 + D48: no first-visit questions, guests are a count only.
2. D46: e-mail code only, no Firebase SDK, no App Check provider.
3. D49: the consent signed is the server's text.
4. D50: calendar file and Google link carry the public page.
5. D47 + D52: booking rules, late-cancellation wording, portal has no form links.
6. this file.

Result: `scripts/test-web.sh full` is green: lint, typecheck, i18n (14 localizations, 406 keys, 0 problems), contrast,
privacy gate, 229 unit tests (2 skipped), production build inside the size budget, Playwright 183 passed / 15 skipped
(Chromium, WebKit, low-end) and the Lighthouse step. Run with `E2E_PORT=4112` because 4010 may be in use.
`scripts/e2e-local.sh` was NOT run here (the coordinator merges and runs it); see "Watch in e2e-local" below.

## What changed, per decision

**D45 first-visit questions.** `FirstVisitStep` (Bk-7) keeps only the optional preference note (it is still sent as
`note`, API.md 5.8, and it still tells her not to write health details). The "how did you hear" and "had it before"
chips, `HeardFrom`, `FirstVisitAnswers.heardFrom/hadBefore` and nine catalog keys are gone. The sealed health-intake path
is untouched. Tests: `booking-machine.test.ts` (the first-visit state is only `note`, the stored draft carries nothing
of the old fields); the mock server still rejects `heardFrom`, `hadBefore`, `firstVisit` and `guestNames` in
`createBooking`.

**D48 guests.** The choice was already a count (0 to `maxGuests`, chips on Bk-2). Removed: the guest-name fields on
Bk-5, `Draft.guestNames`, the `setGuests` names argument, the "named" confirmation line and four catalog keys. The Bk-2
title is now "How many people are coming?" (all 14 localizations). The draft stored in sessionStorage no longer has
names (an old stored `guestNames` is ignored).

**D46 e-mail verification only.**
- Deleted `src/api/firebasePhone.ts`, `src/api/appcheck.ts`, `src/api/verifier.ts`; removed `@firebase/app`,
  `@firebase/app-check`, `@firebase/auth` from `package.json` (lockfile regenerated); `config.ts` and `env.d.ts` lost the
  Firebase config, Auth emulator, App Check and SMS-verifier variables; `.env.e2e*` are now just the API base.
- `useVerification` calls `sendEmailCode` / `verifyEmailCode` directly (API.md 5.5, 5.6). The SMS fallback endpoints of
  the mock (`sendSmsCode`, `verifySmsCode`, not in API.md) are gone. `VerificationProof` is only `{method:'email'}`.
- The e-mail is now **required** on Bk-5 (it is the only thing verified); the booking cannot reach the verify step
  without one (`allowedStep`). The phone stays as the (unverified) contact and the identity for the professional.
  "Find my appointment" (Bk-11) now asks for the e-mail and sends `findBookings {slug, email, verification}`.
- The transport sends no `X-Firebase-AppCheck` header any more (there is no browser-side token).
- `hosting.json` already had `connect-src 'self'` and no third-party origin; unchanged. The privacy gate
  (`scripts/check-privacy.ts`, rule 5) now also fails on any Firebase import, a Firebase dependency in `package.json`, any
  `http(s)://` or wildcard origin in the CSP, or a `connect-src` other than `'self'`.
- Playwright: the booking runs through the e-mail code in every spec; a new test checks that only the page origin is
  called and no SMS/identity/reCAPTCHA URL is touched. Bundle: initial JS about 50 KB gzip; the lazy Firebase chunk
  no longer exists.

**D49 consent.** `getFormContext.consent[locale]` is the only text signed. New pure `routes/form/consent.ts`
(`signableConsent`): the page language, then the nearest she published (same language, her default, English), the
guardian text for a minor; the recorded `textLocaleId` is the language of the text actually shown, `textVersion` is the
server's. With no usable text the whole form shows "This form is not available. Contact the professional" and there is
nothing to tick or send (a minor visit without `guardianText` shows the same notice inside the consent block and cannot be
sent). The `consent-health` and `consent-guardian` embedded drafts are no longer built or shipped (`build-legal.ts`,
`legal/index.ts`); `client-notice`, `data-requests` and `privacy-policy` stay. The guardian's separate photo box came from
the embedded draft and is removed (`consent.photos` is never sent; the payload type no longer has it). Tests: unit
(`intake.test.ts`, 4 new for `signableConsent`), e2e (`sealed.spec.ts`: text comes from the server, adult and guardian;
no consent from the server means no form), new mock scenario `maria-noconsent`.

**D50 calendar.** `calendarEvent` moved to `lib/ics.ts` (testable) and takes the professional's page address
(`pageUrl(slug)` in `lib/config.ts`). The description is "Book again or find your appointment: <page>"; the manage link is
no longer an input of the calendar code at all. Tests: unit (`ics.test.ts`) and e2e (the downloaded file and the Google
link contain the page address and no `/m/`).

**D47 rules of the booking.**
- New `lib/bookingRules.ts` (pure) + `components/BookingRules.tsx`: the heading "These are the rules that apply to this
  booking, from the time you booked" (14 localizations) and one sentence per field of the booking's policy. It is shown
  on the confirmation (the page reads the booking back with `getBooking` after booking; until it answers, or if it fails,
  nothing is shown rather than the current page's rules) and on the management page.
- `getBooking.policy` is the booking's snapshot (API.md 5.11 and the server code `token/getBooking.ts`), so the numbers come
  from the snapshot. The management page no longer shows `rulesText` (see need 1).
- Late-cancellation wording: the published `CancellationPolicy` has no `lateCancelCounts` or `noShowLimit`, so the
  page used to claim "counts as a missed appointment" and "allows up to 3" on its own. Now the cancel row says "After the
  free period, <name> is told right away" and the cancel page has no "counts" warning; the warning and the sentence
  "A late cancellation counts as a missed appointment" appear only if the snapshot carries `lateCancelCounts: true` (and
  `noShowLimit` for the count). After a late cancellation the server's `isLateCancellation` still drives "This one counts as
  a late cancellation".
- Tests: unit `bookingRules.test.ts`; e2e: a booking made under a 48-hour window shows "48 hours" while the page's
  current policy says 24, and no "missed/counts as" wording.

**D52.** The portal (`PortalPage`, `RebookPage`) never linked the form, check-in or my-data pages; they open from the
confirmation and the manage page (`health-form`, `checkin-link`, `my-data`). A Playwright test now fails if the portal
ever gets such a link.

## Needs from the backend

1. **`getBooking.rulesText` is not a snapshot.** `token/getBooking.ts` returns `profile.rulesText` (the professional's
   CURRENT rules text) next to `policy` (the snapshot). To show her own sentences per booking, store the rules text on the
   booking at `createBooking` (or drop the field from `getBooking`). Until then the web words the rules itself from the
   snapshot `policy`; if the app's wording of a rule differs from the web's, the booking page is the one that is consistent.
2. **Late cancellation consequence.** If the product wants the page to warn "this counts as a missed appointment", publish
   `lateCancelCounts` and `noShowLimit` inside the booking's `policy` snapshot (the web already reads them and will show the
   warning only then).
3. **App Check.** The web page cannot produce an App Check token any more (no SDK, D46). `ENFORCE_APP_CHECK` must stay
   `false` for the web functions, or the web needs another bot control (for example the per-IP and per-contact limits that
   exist, or a server-issued challenge). API.md section 2 still says every function takes an App Check token.
4. **API.md 5.5 / 5.7 / 5.9.** 5.5 says e-mail is "the fallback when SMS fails" and `NOT_CONFIGURED` means "show SMS only";
   5.7 describes the browser phone verification. With D46 the e-mail code is the only path, so `NOT_CONFIGURED` on
   `sendEmailCode` is a dead end on the web (the page shows the generic error). `findBookings` by `email` must match
   bookings by the e-mail given at booking (the web now uses only that).
5. `createBooking` with a verified e-mail requires `client.email` equal to the verified address; the web always sends it.

## Watch in e2e-local (not run here)

- `web/test/e2e-local/booking.spec.ts` no longer clicks "use e-mail" (the chip is gone) and no longer answers the removed
  chips; it types the e-mail, reads the code step, and confirms.
- The production build no longer calls `sendSmsCode` or loads Firebase Auth; if `scripts/e2e-local.sh` still sets
  `VITE_SMS_VERIFIER`/`VITE_FIREBASE_CONFIG`, they are now ignored (harmless).
- `findBookings` is now called with `email` and an e-mail proof; the backend e2e should accept that shape (API.md 5.9).

## Not done / left on purpose

- `docs/agent-notes/web.md` still describes the old state (SMS, Firebase chunk, owner decisions of its section 9); this
  file supersedes it for D45 to D52. `DESIGN.md` mentions are the coordinator's.
- The `check` and `consent` block types in `src/legal/index.ts` and `components/Legal.tsx` are now unused by the three
  remaining documents (kept generic; remove with the next legal change).
- The guardian photo agreement (`consent.photos`) has no replacement: if the product wants it, it must be part of the
  professional's `guardianText` (the signed text is hers only, D49).
- No human review of the new strings (all `needs_review`, as the manifest says).
