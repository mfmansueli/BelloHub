# 07 · Localization

**Ten languages, fourteen localizations, from the first screen** (D24). Brazil and Europe open first (D36, wave 1); every other market is built in parallel and opened later. Regions, laws, channels and rollout are in `16-MARKETS.md`; this file is about language, formatting and how strings are built.

Localization is not translation at the end: **every string is written in all fourteen localizations in the same change that adds it** (`CLAUDE.md` §5), the build fails otherwise (`scripts/check-strings.sh`, created in S1), and S11 is the review pass.

## 1. The localizations

| Id | Language | Where it is used | Direction | Address and tone | How it is made |
|---|---|---|---|---|---|
| `pt-BR` | Portuguese (Brazil) | Brazil | LTR | *você*, friendly, direct. **The reference voice.** | Written natively first |
| `pt-PT` | Portuguese (Portugal) | Portugal | LTR | warm and polite, **avoids "você"** ("a sua marcação") | Written natively (not a copy of pt-BR) |
| `es-MX` | Spanish (Mexico) | Mexico, US Spanish speakers | LTR | *tú*, friendly | Written natively |
| `es-419` | Spanish (Latin America) | Argentina, Colombia, Chile, Peru, rest of Latin America | LTR | *tú*-neutral (voseo is **not** used in v1) | **Derived** from `es-MX` (§2.3) |
| `es` | Spanish (Spain) | Spain | LTR | *tú*, friendly | Written natively |
| `en` | English (US) | United States; also the **source language** of the catalog | LTR | friendly and short | Written natively |
| `en-GB` | English (UK) | UK, Ireland, Australia, New Zealand, South Africa, India | LTR | friendly, British spelling (*colour, organise, programme*) | **Derived** from `en` (§2.3) |
| `it` | Italian | Italy | LTR | app: *tu*; client web pages: *tu* (beauty sector register) | Written natively |
| `fr` | French | France (also Belgium, Switzerland, Canada fall back to it) | LTR | **vous** everywhere | Written natively |
| `de` | German | Germany, Austria, Switzerland | LTR | app for the professional: *du*; **client web pages: *Sie*** | Written natively |
| `tr` | Turkish | Turkey | LTR | polite *siz* | Written natively |
| `id` | Indonesian | Indonesia | LTR | app: *kamu*; client web pages: *Anda* | Written natively |
| `hi` | Hindi (Devanagari) | India | LTR | polite *आप*; common English loanwords written in Devanagari where Hindi equivalents sound stiff (*अपॉइंटमेंट*, *क्लाइंट*) | Written natively |
| `ar` | Arabic (Modern Standard, Gulf-friendly vocabulary) | Saudi Arabia, UAE (and any Arabic device) | **RTL** | polite, plain; avoid gendered second-person forms by using noun and infinitive constructions where natural | Written natively |

Rules for every language: no machine-translation tone; no literal copies of English sentence structure; same warmth and brevity as `01-PRODUCT.md` voice; errors say what happened and how to fix it. Ask yourself of each string: *would a professional in that country say it this way to a client?*

> **D41 (2026-10-08): no human review is planned.** `needs_review` stays on every string because it is true; it is information, not a gate.

Mark every string that no native has read as `needs_review` in the catalog (state `needs_review`, the catalog's own mechanism). **`pt-BR` is read by Iago (native) in S3, S6, S10 and S11, and turned to `translated` by the owners only**; Claude Code never promotes a string to reviewed. Until reviewers exist (H10) the app runs in **TestFlight internal only**; public release follows D36.

## 2. iOS implementation

### 2.1 Catalogs and keys
- **String Catalogs**: `Localizable.xcstrings` (source language `en`) and `InfoPlist.xcstrings` (permission texts; display name stays "Bello Hub"). Localizations: `pt-BR`, `pt-PT`, `es-MX`, `es-419`, `es`, `en`, `en-GB`, `it`, `fr`, `de`, `tr`, `id`, `hi`, `ar`. Set `knownRegions` in the project and `CFBundleLocalizations` accordingly (through `Config/App.xcconfig` keys where possible; `check-project-settings.sh` verifies the list).
- **Keys are semantic and hierarchical**: `home.nextUp.title`, `clients.filter.dueToReturn`, `policy.cancel.free24`. Never use the English sentence as the key. `String(localized:)` / `LocalizedStringResource` everywhere, including enum labels and notification texts.
- **Plurals** through catalog plural variations. Languages differ: `pt`, `es`, `it`, `fr`, `de`, `tr`, `en` use `one`/`other` (plus `many` for `fr`, `es`, `it`, `pt` in large-number contexts: let the editor offer the categories); `id` has only `other`; `hi` has `one`/`other`; **`ar` has six categories** (`zero`, `one`, `two`, `few`, `many`, `other`) and every plural key must provide all of them. Never concatenate "1 visit" + "s".
- **Gender and inclusive wording**: prefer neutral constructions ("Cliente", "Persona", "Kund:in" **not**; use "Kundschaft" or the person's name). Where a gendered form is unavoidable use the prototype's convention (`es-MX`: "clienta o cliente"). Do not use gender stars, colons or slashes in German UI; rephrase.
- **Turkish casing**: never call `.uppercased()`/`.lowercased()` on user-facing text without a locale (`İ`/`ı`); use `localizedUppercase` / `uppercased(with:)`. The design avoids all-caps labels, so this mostly matters for search and sorting.

### 2.2 Resolution and settings
- **UI language** follows iOS (per-app language in Settings is the Apple-recommended switch). `LanguageRegion` chooses the **business region and business localization**, which drive: the language of messages she sends, the default booking-page language, ICS and email language, currency preset, week start, phone format. Add an "Open language settings" row that opens the iOS per-app settings (`UIApplication.openSettingsURLString`).
- **Locale resolution test**: launch with `-AppleLanguages (xx) -AppleLocale xx_YY` for every localization and assert one specific string each. Cases that must be checked and recorded in `PROGRESS.md`: Spain vs Latin America Spanish (`es` vs `es-419` vs `es-MX`), Australia/India/South Africa English falling to `en-GB`, Belgium/Canada/Switzerland French falling to `fr`, Austria/Switzerland German falling to `de`, Arabic regions, and Portuguese in Angola/Mozambique falling to `pt-PT`.
- **Business locale vs device locale**: money uses the business currency, formatted with the reader's locale (D25); dates and times use the reader's locale in the **business time zone**; week start defaults from the region and can be overridden.

### 2.3 Derived localizations (one source of truth)
`es-419` is `es-MX` plus a few overrides; `en-GB` is `en` plus spelling and a few overrides. Do not maintain them by hand. Create `scripts/derive-locales.py` (Python 3, standard library only) that reads `Config/Locale/overrides/es-419.json` and `en-GB.json` and rewrites those two localizations in the catalogs from their parents, marking each `needs_review`. `check-strings.sh` fails when a derived localization is out of date. Keep override files small: a missing word in the override means "same as parent".

### 2.4 Formatting
- Only Foundation format styles with an explicit `Locale` argument (`Decimal.FormatStyle.Currency`, `Date.FormatStyle`, `ListFormatStyle`, `Duration.UnitsFormatStyle`, `PersonNameComponents`). **Never** build dates, money or lists by string concatenation. One `Formatters` type in `Managers/Locale/` owns it; views call it.
- **Do not hard-code expected strings from memory in tests.** For each localization generate the expected value from Foundation with that locale, and add a short list of **hand-verified quirks** as separate tests: `es` and `pt-PT` do not group four-digit numbers (`1234,50 €`), `fr` uses a narrow no-break space as the thousands separator, `hi` uses lakh grouping (`₹1,23,456.00`), `ar` shows Arabic-Indic or Western digits depending on the region, `de` writes `1.234,50 €`, `tr` `₺1.234,50`, `pt-BR` `R$ 1.234,50` (with a no-break space).
- **Numerals are the locale's**: let Foundation choose; never force Western digits in `ar`/`hi` UI. Fields that carry data (phone, codes, prices typed by the user) **accept any digit system** and normalize to ASCII digits before storing (`DigitNormalizer`, pure, tested with Arabic-Indic `٠١٢٣٤٥٦٧٨٩`, Extended Arabic-Indic `۰۱۲۳۴۵۶۷۸۹` and Devanagari `०१२३४५६७८९`).
- **Week start and clock** default from Foundation for the region (`Calendar(identifier: .gregorian)` with the region locale, `Locale.hourCycle`) and are stored in `LocalePrefs`, so she can override. Tests assert these known defaults: US Sunday/12 h, BR Sunday/24 h, MX Sunday/12 h, ES Monday/24 h, PT Sunday/24 h, DE Monday/24 h, FR Monday/24 h, IT Monday/24 h, GB Monday/24 h. For other regions the test only asserts the value is the Foundation value (do not assert from memory).
- **Calendar system**: Gregorian everywhere in v1, also for `ar` and `hi`. Do not switch to Hijri or other calendars automatically.
- **Phone numbers**: store E.164. `PhoneFormatter` and `PhoneNormalizer` use `regions.json` (`16-MARKETS.md`); country picker lists the preset countries first, then all regions (data file with calling codes, no third-party library).
- **Time zones**: appointments are UTC instants plus the business `timeZoneID`. The app renders in the business zone and, when the device zone differs, shows "Business time" under the time. DST tests per `16-MARKETS.md` §3.
- **Sorting and search** use `localizedStandardCompare` and diacritic- and width-insensitive matching (client "María" is found by "maria"; Turkish "İlker" by "ilker"; Arabic names with or without diacritics).

### 2.5 Right-to-left (Arabic) and scripts
- SwiftUI mirrors layouts when the language is right-to-left. You keep it correct by rules: use `leading`/`trailing`, never `left`/`right`; no `.offset(x:)` with a hard-coded sign (use a `layoutDirection`-aware helper `Directional.x(_:)` for motion); `HStack` order is semantic; SF Symbols with a direction are used as `chevron.forward`/`chevron.backward`, `arrow.forward`, etc. (the system mirrors them); symbols that must **not** mirror (clock, check, play, camera, phone) stay plain; images and illustrations that carry direction are mirrored with `flipsForRightToLeftLayoutDirection(true)`; the before/after slider mirrors; the week grid mirrors (the first weekday column is on the right in `ar`); progress bars fill from the leading edge.
- **Bidirectional text**: names, phone numbers, times, URLs and Latin brand names inside Arabic text must not scramble. Wrap interpolated values in Unicode isolates (`\u{2068}` … `\u{2069}`) in message templates and notification texts through one helper (`BidiIsolate.wrap(_:)`, tested). Phone numbers are always shown left-to-right inside RTL text.
- **Fonts**: Fraunces and DM Sans cover Latin and Latin Extended (including Turkish, Vietnamese). They contain no Arabic or Devanagari glyphs; iOS falls back per glyph to the system fonts (SF Arabic, Devanagari system font). Do **not** bundle other fonts in v1. Verify in the Design Catalog and screenshots: baseline alignment, weights that look balanced (use `.semibold` where Fraunces 500 would look thin next to the fallback), and a **line-height multiplier of 1.15** for `ar` and `hi` text (a `Typography` token that reads `Locale.current.language`, tested).
- **Text expansion**: German +35 %, French +25 %, Italian, Portuguese, Spanish and Turkish +20–30 %, Indonesian +15 %; Hindi and Arabic are shorter in width but taller. No fixed text widths; `ViewThatFits`, `lineLimit(nil)` where meaning matters, `minimumScaleFactor` only for numerals. Test with the Double-Length and Accented pseudolanguages, a right-to-left pseudolanguage (Xcode scheme option), and at AX5.

## 3. Settings model

`LocalePrefs`: `businessLocalizationID` (one of the fourteen, default from the device region and language), `regionCode` (a `RegionPreset`), `currencyCode`, `weekStart`, `use24Hour`, `bookingLocaleIDs` (languages the public page offers; the business localization is always on). The preset suggests `bookingLocaleIDs` (for Brazil: `pt-BR` and `en`). Changing the business localization re-renders previews instantly and never rewrites past messages or records. Stored in the vault (non-sensitive), published to `publicProfiles` (`locales`, `defaultLocale`, `currencyCode`, `timeZoneID`, `regionCode`).

## 4. Glossary and vocabulary

`docs/strings/glossary.csv` is the **single source** for product terms. It currently has columns for `pt-BR, pt-PT, es-MX, es, en` (46 terms). **In S1 extend it** with columns `es-419` (derived), `en-GB` (derived), `it`, `fr`, `de`, `tr`, `id`, `hi`, `ar`, writing each term natively in the product voice, and keep the file the one place where a product term is decided. Rules: one term, one translation, everywhere (app, web, emails, templates).

Fixed choices (do not drift): `pt-PT` *marcação, desmarcar, telemóvel*; `pt-BR` *agendamento, cancelar, celular*; Spain *cita, móvil*; Mexico *cita, celular, inasistencia* (no-show); Italian *appuntamento, annullare, spostare*; French *rendez-vous, annuler, déplacer*; German *Termin, absagen, verschieben*; Turkish *randevu, iptal et, ertele*; Indonesian *janji temu, batalkan, jadwalkan ulang*; Hindi *अपॉइंटमेंट, रद्द करें, समय बदलें*; Arabic *موعد، إلغاء، إعادة جدولة*. The profession's own term for the person she serves (client, patient, student) is chosen in onboarding (`Onb-5-Terminology`) and overrides "client" throughout the **professional** app; the public page uses neutral wording.

## 5. Profession catalog

`Resources/Professions/professions-<localization>.json` (flat in the bundle, so the name carries the language): per profession the localized name, suggested services (name, default minutes), suggested tags, default record fields, default follow-up weeks, default contraindications, and terminology options. The prototype's English lists (`Onb-2…Onb-6b`) are the **seed**; write each language natively (Brazil in `16-MARKETS.md` §4; Spain: *esteticista, peluquería, manicura, cejas y pestañas, barbería, micropigmentación y tatuaje, masajista*), not as literal translations. `es-419` and `en-GB` are copies of `es-MX` and `en` with a few names replaced (S3 wrote them in full: the app loads one file per language and never merges). `scripts/check-professions.sh` requires every file to have the same professions, keys, minutes, follow-ups and defaults as English, so a translation can never change behavior; when a language genuinely needs different services, relax that check for it and say why. Mark generated copy `needs_review` for a human native reader (H10). Data, not code: adding a profession never changes Swift. Professions and services that are culturally different are allowed to differ by language (for example henna brows in `hi`/`ar`/`id`, hammam-style massage in `tr`, threading in `hi`); do not add a profession that has no screen support, only catalog entries.

## 6. Message templates

`docs/strings/message-templates.json` has, per locale, the confirmation, reminder, running-late and birthday messages exactly as the prototype shows them, with placeholders `{name} {service} {professional} {date} {time} {deadline} {minutes} {link}`. **Extend it** to the nine missing localizations (derived ones by the script). You must add in all localizations, in the same voice and with the same placeholders: `followUp`, `winBack`, `aftercareLink`, `blockedDay`, `cancelledByPro`, `waitlistOffer`, `reminderConfirmRequest`, `noShowFollowUp`, `rescheduleAccepted`, `rescheduleDeclined`, `bookingApproved`, `bookingDeclined`. Rendering fills placeholders with locale-aware dates (`{date}` = "jueves 1 de octubre" without the year; `{deadline}` = date and time) and wraps values with `BidiIsolate` for `ar`. The professional can edit her own quick replies in her locale (`QuickReplies`); the built-ins are defaults. **No message ever contains clinical content** (`06` §8). Links use the configured base URL (`BELLO_WEB_BASE_URL`; the prototype's `bello.app/…` and `bellohub.app/…` strings are placeholders for it).

## 7. The web booking pages

- Language selection order: explicit choice in the language sheet (`Bk-1`), then `navigator.languages` matched to the languages the professional offers, then her default. Persist only the language code in `localStorage` (non-sensitive). The chooser lists only the languages she offers, each in its own name (*Português (Brasil)*, *Español*, *English*, *العربية*, *हिन्दी*…).
- `<html lang>` and **`dir="rtl"` for `ar`** set per language; CSS uses **logical properties** (`margin-inline-start`, `padding-inline`, `inset-inline-end`, `text-align: start`) and never `left`/`right`; flex and grid follow `dir`; mirrored icons through CSS (`[dir=rtl] .icon-dir { transform: scaleX(-1) }`). Names, phone numbers and times inside text use `<bdi>` or `unicode-bidi: isolate`.
- `Intl.DateTimeFormat` with the **business** `timeZone`, `Intl.NumberFormat` with the business currency, `Intl.PluralRules` for plurals (Arabic has six forms), `Intl.ListFormat`. Strings come from JSON files per locale (`web/src/i18n/<localization>.json`), the same glossary, tone and key naming scheme. A build step fails on missing keys or placeholders. Derived locales (`es-419`, `en-GB`) are produced by the same `derive-locales.py`.
- **Fonts on the web**: Fraunces and DM Sans subsets for Latin only (`unicode-range`), system font stacks for Arabic and Devanagari (`system-ui`, `"Noto Sans Arabic"`, `"Noto Sans Devanagari"` as optional local names, no downloads), keeping the initial payload budget (`10-WEB-BOOKING.md`).
- **Digits typed by the client** (phone, SMS code): accept Arabic-Indic, Extended Arabic-Indic and Devanagari digits and convert to ASCII before sending. The code field uses `inputmode="numeric"` and `autocomplete="one-time-code"`.
- The rule text ("Changes are free up to 24 hours before…") is generated from the professional's policy values **and published per locale** so the iPhone and the web can never disagree (`CancelPolicy` produces it; `RD` templates in the prototype's `Bk-1-Page` show the expected phrasing in the five prototype locales; write the others in the same pattern).
- ICS files and emails use the business locale unless the client's page language differs (then her page language). ICS `SUMMARY`/`DESCRIPTION` carry bidi isolates in `ar`.

## 8. Legal texts (`LEGAL-REVIEW`)

**D55:** consents are the professional's own business; the app only records their status. Bello Hub writes no consent, treatment-agreement, photo-consent or guardian text, so the three consent documents below are no longer produced, shipped or shown anywhere (the 2026-10 drafts stay in `legal/` as history only). The app bundle holds no legal text at all: `BelloHub/Resources/Legal/` and `scripts/sync-legal-resources` / `check-legal-resources` are gone; the app's own consent strings are the `health.consent.*` and `consent.*` keys of `Config/Locale/strings/s4-health-forms.json` (a status record, never a text to sign).

Stored as versioned documents `legal/<doc>/<localization>/<version>.md`, rendered in the app and on the web, referenced by `textVersion`. **All fourteen localizations get provisional drafts**, but because the legal frameworks differ, write them in **region sets**: Brazil (`pt-BR`, LGPD), Portugal (`pt-PT`), Spain (`es`), Mexico (`es-MX`), Latin America (`es-419`, generic with country notes), United States (`en`), English-speaking markets (`en-GB`, UK GDPR), Italy, France, Germany, Turkey, Indonesia, India (`hi` and `en-GB`), Arabic markets (`ar`). Each draft is marked in file headers and `legal/STATUS.md` (`draft | reviewed`, reviewer, date); the professional-facing app does not show "draft". Start with Brazil and the European core and write them most carefully (D36).

| Document | Must say (engineering checklist) |
|---|---|
| Terms for the professional + Data Processing Agreement | roles (controller / processor), what Bello hosts, sub-processors (Google Firebase, email provider), security measures (`06`), her duties (lawful basis, consent, retention), breach notice, deletion on termination. |
| Privacy policy (app and site) | data categories by class (`06` §1), purposes, legal bases per market, retention (D30), rights and how to exercise them, international transfers, sub-processors, contact, the honest limits of E2EE (`06` §6). |
| Client notice on the booking page | who is the controller (the professional), what is collected to book, rules of cancellation, link to the privacy policy. |
| ~~Health-form consent~~ | Not produced (D55). |
| ~~Photo consent~~ | Not produced (D55). |
| ~~Guardian consent (minors)~~ | Not produced (D55). |
| Data-subject requests | wording for copy and deletion requests and the professional's confirmation. |

The professional's acceptance of the terms stores `textVersion`, localization and timestamp. Nothing a client reads on the web is signed.

## 9. Tests and tooling

- `scripts/check-strings.sh` (**create it in S1**, extend as you go): fails on a missing key in any of the fourteen localizations, empty value, plural category missing (all six for `ar`), placeholder mismatch (`%@`, `%lld`, `{name}` must appear in every localization), untranslated hard-coded string in `Screens/` (regex for `Text("` literals with spaces), keys in code absent from the catalog, a derived localization out of date, and — only in S11 and later — any `needs_review` outside the allowed list in `PROGRESS.md`. It also prints a coverage table (languages × percentage translated × percentage reviewed).
- `scripts/export-strings.sh` exports a localization (or all) as spreadsheets `build/strings-<id>.csv` (app, both catalogs) and `build/web-strings-<id>.csv` (booking pages) with columns `key, en, <localization>, comment, state` for human reviewers, and `scripts/import-strings.sh` reads corrections back into the batches (never into a catalog); `--reviewed` records approvals in `Config/Locale/reviewed/` so they survive merges (H10, `docs/review/README.md`).
- **S11 additions:** `check-strings.sh --final` also enforces the style rules a script can see (one address per audience: *du*/*tu*/*kamu*/*siz* to the professional, *Sie*/*Anda*/*siz* in client texts; pt-PT never *você*; regional vocabulary per the glossary; no gender slashes, stars or brackets; Arabic punctuation; American `en`, British `en-GB`), the same rules on `web/src/i18n`, the glossary and the message templates; `NavigationTitleFitTests` measures every navigation title in every localization; `ClientTerm.countText` (`term.*.count`) gives counted nouns their plural form; `LocalizationScreenshotUITests` is the screenshots test.
- Formatter tests per localization (§2.4), locale-resolution tests (§2.2), digit and bidi helper tests (§2.5), `PhoneNormalizer` tests per preset.
- Snapshot-style UI test per localization for ten key screens (Home, Clients, Calendar, ClientProfile, NewAppointment, BookingSettings, CancelPolicy, LanguageRegion, Privacy, RecoveryKey) at default size and AX3, asserting no truncation of primary actions (accessibility element frames and `isHittable`); for `ar` also assert that the first tab is on the right and the back chevron points right.
- Web: unit tests of every locale JSON against the key list; Playwright runs the booking flow in each language (and in RTL) and checks the rendered rule text equals the published rule text.
- Human tasks: native review of the languages (H10), legal review (H11).
