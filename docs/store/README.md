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
- Terms in each language follow `docs/strings/glossary.csv` and the screen names the app shows (More > Booking page,
  More > Account > Delete account, Alerts).

Open before submission:

1. The terms and privacy URLs in the descriptions (`https://bellohub.app/legal/terms`, `/legal/privacy`) need the domain
   (H6); until then use the Hosting address, or leave the lines out and fill the two URL fields of App Store Connect.
2. Screenshots per localization (`LocalizationScreenshotUITests` produces the raw material).
3. The booking link in TestFlight is the preview address (D54); the notes say so.
