# docs/store: App Store Connect drafts (S12)

What a human pastes into App Store Connect for H14. Engineering drafts written 2026-10-10 on `s8-leftovers`; no native
review yet (D41: no human language review before launch, so read them once in the languages you know).

| File | Contents |
|---|---|
| `app-privacy.md` | App Privacy answers, data type by data type, and the privacy manifest explained |
| `pt-BR.md`, `pt-PT.md`, `es.md`, `it.md`, `fr.md`, `de.md`, `en-GB.md` | Brazil and Europe first (`docs/16-MARKETS.md`) |
| `en.md`, `es-MX.md`, `tr.md`, `id.md`, `hi.md`, `ar.md` | The other storefront localizations. `es-MX` is App Store Connect's "Spanish (Mexico)" and also serves Latin America (the app's `es-419` is derived from it) |

Each file has the name (≤ 30 characters), subtitle (≤ 30), keywords (≤ 100, comma-separated with no spaces, words not
repeated from the name), promotional text (≤ 170, editable without a new build), the description (≤ 4000), "What's new"
for 1.0 and the TestFlight "What to test" notes. Every length was checked when the files were written; the counts are in
the files. If you edit a field, recount (App Store Connect shows the counter).

Rules the texts follow:

- Copy rules of `docs/06-PRIVACY-SECURITY.md` section 12: "Your records stay on your iPhone and in your iCloud",
  "Bello Hub can't read your clients' health forms", "encrypted"; never "GDPR compliant", "unhackable" or an absolute
  claim about Apple or iCloud.
- Only features in this build. Voice notes are not claimed (the app's voice capture is unavailable in v1); the portal and
  check-ins are not claimed either.
- Product rule 1: no payments, no invoices; the only charge is Bello Hub Pro, described with the auto-renewal sentence
  Apple expects (first 10 clients free, D42; no trial).
- The description opens with the approved marketing phrase in that language (`docs/MARKETING.md`, 2026-10-11); it is a
  line of tone, not a feature claim.
- Terms in each language follow `docs/strings/glossary.csv` and the screen names the app shows (More > Booking page,
  More > Account > Delete account, Alerts).

Open before submission:

1. The terms and privacy URLs in the descriptions (`https://bellohub.app/legal/terms`, `/legal/privacy`) need the domain
   (H6); until then use the Hosting address, or leave the lines out and fill the two URL fields of App Store Connect.
2. Screenshots per localization (`LocalizationScreenshotUITests` produces the raw material).
3. The booking link in TestFlight is the preview address (D54); the notes say so.

## TestFlight (v1.0.0 release candidate, S12)

The per-language "What to test" notes are in each file. For the build itself (H14, H16):

1. Archive from a **release** Xcode (Xcode 27 build 27A266a looks like a release build; confirm in About Xcode), scheme
   `BelloHub`, configuration Release, team `X5392U638Q`, bundle id `com.bellohub`. The tag `v1.0.0-rc1` marks the
   commit to archive. `scripts/check-warnings.sh` was clean on it.
2. Before uploading: deploy the CloudKit schema to Production (H2), create the two subscription products of D42 in
   App Store Connect and install Apple's root certificates on the server (H14), otherwise `syncPlan` answers
   NOT_CONFIGURED and a sandbox purchase does not lift the server's 10-client limit.
3. App Privacy: paste the answers of `app-privacy.md`; the privacy manifest (`PrivacyInfo.xcprivacy`) is in the
   build and `scripts/check-privacy.sh` passes.
4. Export compliance: `ITSAppUsesNonExemptEncryption = NO` is set (standard encryption only).
5. Internal testers first (the two owners on real iPhones, H3): the VoiceOver pass of
   `docs/agent-notes/accessibility-audit.md` section 3, scrolling 2,000 clients with Instruments (hitches), Face ID,
   camera, contacts import, Apple Calendar switch (a "Bello Hub" calendar appears with the week's visits), push for a
   booking from the web page, recovery key on a second iPhone.
6. Known limits to tell testers: sign-in is Apple only; voice notes say "not available yet"; the booking link is the
   preview address `https://bello-hub.web.app/<slug>` until the domain exists (H6, D54); e-mail confirmations are off
   until the e-mail provider key is set (H7).
