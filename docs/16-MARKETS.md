# 16 · Markets, rollout and regional rules

Bello Hub is built for **many markets from the first commit** and **opened to the public one market at a time**. The code supports every market in this file; what is *open* is decided in App Store Connect (D36) and recorded in `legal/STATUS.md`.

**First markets: Brazil and Europe, both top priority, opened together (wave 1).** Everything in the product is first written, read and judged in `pt-BR`; the European languages of wave 1 (`pt-PT`, `es`, `it`, `fr`, `de`, `en`, `en-GB`) get the same care. Then the rest.

Why these markets: they are large Apple-device markets where **WhatsApp is the everyday business channel** between a professional and her clients (D14, D31). Markets where another app dominates (China, Japan, South Korea) are out of scope for v1.

Language and formatting rules live in `07-LOCALIZATION.md`. Legal texts live in `legal/` (`07-LOCALIZATION.md` §8). This file is about *regions*.

## 1. Region presets (data, not code)

`BelloHub/Resources/Regions/regions.json` is the single table; a `RegionPreset` model in `Models/` reads it and a `RegionCatalog` (pure) answers questions. The professional's **business region** (chosen in onboarding from the device region, changeable in `LanguageRegion` 7.2) selects the preset. A preset gives defaults; she can override currency, week start and clock.

Fields: `code` (ISO 3166-1 alpha-2), `defaultCurrency`, `callingCode`, `phoneGroups` (display pattern), `defaultLocalization`, `localizations` (those offered for the booking page, first is default), `messagingChannel` (`whatsapp` | `messages`), `privacyFrameworkId`, `healthDataResidency` (`none` | `review` | `blocking-until-reviewed`), `wave` (1–4), `timeZones` (IANA ids offered first).

| Region | Currency | Calling | App / page languages | Messaging | Privacy framework (confirm with a lawyer, H11) | Residency | Wave |
|---|---|---|---|---|---|---|---|
| `BR` Brazil | BRL | +55 | `pt-BR` (+ `en`) | WhatsApp | LGPD (Lei 13.709/2018, health data is "sensível", Art. 11); ANPD | none | **1** |
| `PT` Portugal | EUR | +351 | `pt-PT` (+ `en`) | WhatsApp | RGPD + Lei 58/2019; CNPD | none | 1 |
| `ES` Spain | EUR | +34 | `es` (+ `en`) | WhatsApp | RGPD + LOPDGDD; AEPD | none | 1 |
| `MX` Mexico | MXN | +52 | `es-MX` (+ `en`) | WhatsApp | LFPDPPP (rewritten in 2025; confirm the current text) | none | 2 |
| `US` United States | USD | +1 | `en` (+ `es-MX` for Spanish-speaking clients) | Messages, WhatsApp if she prefers | State laws (CCPA/CPRA, Washington My Health My Data, Nevada, Connecticut…); HIPAA applicability to be confirmed | review | 2 |
| `AR` `CO` `CL` `PE` and the rest of Spanish-speaking Latin America | ARS COP CLP PEN (by country) | +54 +57 +56 +51 | `es-419` (+ `en`) | WhatsApp | AR Ley 25.326, CO Ley 1581/2012, CL Ley 21.719 (new, in force from December 2026; confirm), PE Ley 29.733 | none | 2 |
| `IT` Italy | EUR | +39 | `it` (+ `en`) | WhatsApp | GDPR + Codice Privacy (D.Lgs. 196/2003 as amended); Garante | none | 1 |
| `FR` France | EUR | +33 | `fr` (+ `en`) | WhatsApp | RGPD + Loi Informatique et Libertés; CNIL. Ask the lawyer whether the French health-data hosting certification (HDS) applies to sealed envelopes we cannot read. | review | 1 |
| `DE` Germany (and `AT`, `CH`) | EUR / CHF | +49 +43 +41 | `de` (+ `en`) | WhatsApp | DSGVO + BDSG; Art. 9 special category. Business pages in Germany and Austria usually need a legal notice (*Impressum*): ask the lawyer; if required, add an optional "Legal notice" text to the public page as a **design addition**. | none | 1 |
| `GB` United Kingdom, `IE`, `AU`, `NZ`, `ZA` | GBP EUR AUD NZD ZAR | +44 +353 +61 +64 +27 | `en-GB` (+ `en`) | WhatsApp (AU: Messages or WhatsApp) | UK GDPR + DPA 2018; EU GDPR (IE); Privacy Act 1988 (AU, health information is sensitive); POPIA (ZA) | none | 1 (`GB`, `IE`); 2 (`AU`, `NZ`, `ZA`) |
| `IN` India | INR | +91 | `hi` and `en-GB` | WhatsApp | DPDP Act 2023 and its rules (phased; confirm status) | review | 3 |
| `TR` Turkey | TRY | +90 | `tr` (+ `en`) | WhatsApp | KVKK (Law 6698; health data is special category, explicit consent; cross-border transfer rules); controller registration (VERBIS) to confirm | review | 3 |
| `ID` Indonesia | IDR | +62 | `id` (+ `en`) | WhatsApp | PDP Law (Law 27/2022; health data is "specific" data) | review | 3 |
| `SA` Saudi Arabia | SAR | +966 | `ar` (+ `en`) | WhatsApp | PDPL (in force 2023–24); transfer restrictions; health data | **blocking-until-reviewed** | 4 |
| `AE` United Arab Emirates | AED | +971 | `ar` (+ `en`) | WhatsApp | Federal PDPL (Decree-Law 45/2021); **Federal Law 2/2019 restricts moving health data outside the UAE**; free zones (DIFC, ADGM) have their own rules | **blocking-until-reviewed** | 4 |

`healthDataResidency` is information for the humans and the rollout, not a runtime switch: **no region ever gets clinical data on our servers** (D2, D21), so residency risk is limited to the sealed envelope in transit (30 days at most, ciphertext) and to account/booking metadata. Still, wave 4 regions are not opened without legal sign-off, and the lawyer may require an in-country option; that would be a new decision, not a quiet change.

If the device region is not in the table, use the closest preset by language (for example `NL` → `en-GB` + EUR) and let her pick currency and region manually. Never block sign-up in code: availability is controlled by the App Store storefront list (D36).

## 2. Rollout waves

| Wave | Markets | Ready to open when |
|---|---|---|
| 1 | **Brazil and Europe**: Brazil; Portugal, Spain, Italy, France, Germany/Austria/Switzerland, United Kingdom, Ireland | for Brazil: `pt-BR` read by a native (Iago) and the LGPD texts reviewed by a lawyer. For Europe: `pt-PT`, `es`, `it`, `fr`, `de`, `en`, `en-GB` each read by a native, and the European legal set (common GDPR core plus national annexes PT, ES, IT, FR, DE, UK) reviewed by a lawyer; EU trader declaration done in App Store Connect (H16). For both: two real iPhones tested sync and voice; the web link tested inside WhatsApp and Instagram in-app browsers (H8). Brazil and Europe may open on different days if one is ready first; neither waits for waves 2 to 4 |
| 2 | Mexico, United States, Spanish-speaking Latin America, Australia, New Zealand, South Africa | each language read by a native; each legal set reviewed |
| 3 | India, Turkey, Indonesia | same; plus the notes in the table |
| 4 | Saudi Arabia, United Arab Emirates | same; plus a written residency opinion; right-to-left screens reviewed by a native |

How it is enforced: **App Store Connect → Pricing and Availability → countries and regions** lists only the open markets (H15). The code does not gate sign-up. `legal/STATUS.md` (you create and maintain it; `scripts/check-legal-status.sh` prints it) lists every legal document × localization with `draft | reviewed`, the reviewer and the date. `PROGRESS.md` shows the same table at the top as "Market readiness".

## 3. Channels per region

- **WhatsApp links** (`https://wa.me/<E.164digits>?text=<percent-encoded>`) work in every region above, for both WhatsApp and WhatsApp Business. Digits only after normalizing Arabic-Indic and Devanagari digits and stripping `+`, spaces, dashes and a leading trunk `0` for the region's calling code (`PhoneNormalizer`, pure, tested with numbers from every preset). In `US` the default channel is Messages (SMS/iMessage); she can switch to WhatsApp.
- **SMS verification codes** (Firebase Auth phone) are the weakest link in some regions: operator registration rules and filtering make delivery slow or unreliable in India, Indonesia, Turkey, Saudi Arabia and the UAE, and SMS pumping fraud targets premium routes. So (D37): (a) configure the **SMS region policy as an allow-list** of the preset countries only; (b) the verify screen (`Bk-6`) **always offers "Use email instead"**; (c) a budget alert on SMS spend; (d) when WhatsApp Cloud API is enabled (D31, H13) a WhatsApp code can replace SMS per region without UI changes (`ClientMessenger` chooses by `regions.json`).
- **WhatsApp Cloud API templates** (future, H13): one template set per language; appointment confirmations and reminders belong to the *utility* category, win-back and birthday messages to *marketing* (different price and opt-in rules). Keep the approved template names in `firebase/functions/src/messaging/templates.ts` keyed by localization, and keep the same placeholders as `message-templates.json`.
- **Time zones**: presets list the common IANA zones first (Brazil has four civil zones: `America/Noronha` (UTC−2), `America/Sao_Paulo` (−3, most of the population), `America/Manaus` (−4) and `America/Rio_Branco` (−5); Mexico has several; the US several; Indonesia three; India one, no DST; Saudi one, no DST). DST tests use zones that change: `Europe/Lisbon`, `Europe/Madrid`, `Europe/Rome`, `Europe/Berlin`, `Europe/London`, `Europe/Istanbul` (fixed UTC+3), `America/New_York`, `America/Sao_Paulo` (no DST since 2019), `America/Mexico_City` (no DST since 2022).

## 4. Brazil-first details

- `pt-BR` is the reference voice. When a string's tone is in doubt in any language, check how it reads in `pt-BR` first.
- Profession catalog for Brazil is written with the terms professionals actually use: *manicure e pedicure, designer de sobrancelhas, lash designer, esteticista, cabeleireira(o), barbeiro, micropigmentadora(or), massoterapeuta, tatuador(a)*; services such as *design com henna, brow lamination, alongamento de cílios fio a fio, limpeza de pele, drenagem linfática, blindagem de unhas*. Keep gender-neutral forms in UI and ask her preferred title in onboarding when a word is gendered.
- Phone input for Brazil accepts `(11) 91234-5678`, `11912345678` and `+55 11 91234-5678`; stores E.164 (`+5511912345678`). Mobile numbers have nine digits after the area code.
- Do **not** collect CPF, RG or other national ids anywhere (data minimization). Names, phone, optional email and birth date (optional) only.
- Dates read `qui., 8 de out.`; times `14:30`; money `R$ 120,00`; week starts Sunday; the web link defaults to `pt-BR`.
- Default booking-page languages for a Brazilian professional: `pt-BR` plus `en`.
- LGPD points the lawyer must cover: legal basis for health data (explicit consent, Art. 11), the professional as *controladora* and Bello Hub as *operadora*, data-subject rights channel, international transfer (servers in the EU), retention, incident notice to ANPD and holders.

## 5. What you build for this file

1. `regions.json`, `RegionPreset`, `RegionCatalog`, `PhoneNormalizer`, `PhoneFormatter` with tests for every preset (S1/S3).
2. `LanguageRegion` (7.2) using the presets (S10); onboarding picks the preset from the device region.
3. `legal/STATUS.md`, `scripts/check-legal-status.sh` (S11).
4. SMS region allow-list generated from `regions.json` (`firebase/scripts/sms-regions.mjs` prints the list for H4).
5. Unit tests: every preset has a currency, calling code, at least one offered localization that exists in the catalog, and a messaging channel; every `wave` is 1–4; the Brazil, Portugal, Spain, Italy, France, Germany, United Kingdom and Ireland presets are wave 1.
