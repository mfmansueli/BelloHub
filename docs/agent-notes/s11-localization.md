# S11 · Localization completion and market readiness (agent notes)

Single agent on `build/v1`, from `4a12a51` (2026-10-10). Scratch tools lived in the session scratchpad only; everything
that stays is in `scripts/`, the batches, the tests and the docs listed below.

## 1. What the string audit found (and fixed)

The batches were complete (every key in all fourteen localizations, plurals and placeholders consistent), so the
problems were of the kind a completeness check cannot see. In order of size:

| Finding | Where | Fix |
|---|---|---|
| **German spoke to the professional with *Sie* on S3 to S6 screens** (about 330 strings) and with *du* on S7 to S10 | de | Every app string in *du*; client-facing texts (messages, rules, booking page, QR card, share texts) keep *Sie*. Rule enforced by `check-strings.sh` |
| **Indonesian app strings said *Anda*** (354) although the app register is *kamu* | id | Converted; client texts keep *Anda* |
| **Turkish S10/S7/S8 strings were in the informal *sen*** (about 180), the rest in *siz*; S8 used *danışan* instead of the glossary *müşteri* | tr | All *siz*; *müşteri* |
| **German gendered forms**: *Kundin/Kundinnen* (67 strings), *Kunde/Kundin*, *Patient/in*, *Schüler/innen*, profession names *Kosmetiker/in* | de | *Kundschaft* for the clientele, *Person/Personen* for counts and one person, fields for professions (*Kosmetik*, *Haare*...) |
| **French, Spanish, Portuguese and Italian S10 screens said *clientes/clientas/clienti* in the feminine plural** while the rest of the app (and the Clients tab) used the generic plural | fr, es, es-MX, pt-BR, pt-PT, it | Generic plural everywhere; French neutral constructions instead of *vous seule* (app and web) |
| **pt-PT said *você*** (15) and *cancelar* for appointments | pt-PT | *si*/omitted subject; *desmarcar* (glossary) |
| **en-GB had no overrides at all** (it was a copy of en); `en` had British spellings (*authorises*, *colour*, *tick*) | en, en-GB | en American; 34 en-GB overrides |
| **Counted nouns chose singular/plural by `count == 1`**: "12 Kundschaft" in German, wrong forms for 0 in fr/pt and for 3-10/11+ in Arabic | all | `ClientTerm.countText` + `term.*.count` plural keys (Arabic six forms); the count sentences take the counted phrase ("Not back in 2+ months: 3 clients"). Tests: `ClientTermCountTests` |
| Arabic plurals: duals written with the numeral ("2 ساعتان"), one-forms with a number | ar | Dual and singular forms without a numeral |
| Term drift against the glossary: de *Nachfassen/Nachkontrolle/Folgetermin*, *Tarif/Plan/Abo*, *Patch-Test*; it *Controllo/follow-up/Richiamo*; pt-PT *acompanhamento*, *ligação* for link; fr *forfait/offre/abonnement* | de, it, pt-PT, fr | One word per term; glossary updated where the app's choice was the better one (fr *lien de réservation*, *test cutané*; it *patch test*; short no-show forms; tr *Uyarılar*) |
| Calendar tab "Calendario" in es/it vs glossary "Agenda" | es, es-MX, it | Agenda |
| **Stale facts**: "by email if you share one" (email is required, D46), forms "signed" (D55), "recovery phrase" (it is a key), "consent text" on the forms row | all | Rewritten in all fourteen |
| Two keys authored by two batches (`bookingSettings.link.notOnline`, `shareLink.address.offline`) | s5/s8 | Removed from s5; `merge-strings.py` now refuses duplicates |
| InfoPlist permission texts could only be edited by hand; de/id used the wrong register | InfoPlist | `Config/Locale/infoplist/infoplist.json` merged by the script; derived localizations for both catalogs |
| Gendered client terms with slashes/brackets (*invitado/a*, *convidado(a)*, *allievo/a*, *invité(e)*) | es, pt, it, fr | Generic forms (they are tab titles and must fit) |
| Profession names with slashes/brackets | de, pt, it, fr, es-419, ar | Fields (*Cabelo*, *Acconciatura*, *Coiffure*, *التجميل*...) |

Not changed on purpose: singular feminine forms where English says "she" (*la clienta*, *a cliente*) read naturally
in es/pt/it; *check-in* stays as an anglicism in pt/it/fr/de (salons use it), not in es.

## 2. New gates and tests

- `scripts/check-strings.sh --final` (run by `test.sh fast`): style rules (address per audience, regional words,
  gender slashes, Arabic punctuation, US/UK spelling) on the app catalogs **and** `web/src/i18n`; glossary has every
  term in every localization; message templates have every kind with English's placeholders; navigation-title lists
  in step with the screens; `needs_review` only in localizations listed under "Strings awaiting reviewers" in PROGRESS.
- `NavigationTitleFitTests`: every navigation title measured with the bar's fonts in every localization (large 34 pt
  bold within 343 pt; inline 17 pt semibold within 250 pt). It found ~25 titles that truncated (the known pt-BR
  "Pedido de agendamen…" on 2.10, but also English "Cancellations and cha…"). Fix: settings-like pushed screens and
  request screens use inline titles (iOS Settings style); a few titles shortened.
- `LocalizationScreenshotUITests` (Full plan, skipped by UISmoke): key screens in all fourteen localizations with the
  text-clipped audit **including navigation bars**, Arabic mirroring (first tab and back button on the right), a
  double-length pseudolanguage. The accessibility audit does not report a truncated large title (it reported nothing
  on 2.10 while the screenshot showed the ellipsis), which is why the width test exists. It found chip labels wrapping
  ("12 hr"): `FlowLayout` now places one-line children at their natural size.
- `ClientTermCountTests`; functions `ics.test.ts` and `messaging.test.ts` per localization (folding with Turkish,
  Devanagari, Arabic names; isolates only in Arabic; every email rendered); web `ics.test.ts` per locale file.
- `scripts/import-strings.sh --self-test` (round trip on copies of the batches) in `test.sh fast`.

- **The pt-BR, de and hi audit runs of S6 to S8, never finished, are done**, together with every other audit suite
  (14 suites x `en`, `pt-BR`, `de`, `ar`, `hi` x default size and AX5; `docs/agent-notes/audits-s6-s8.md`). Real
  problems found: recovery-key words cut in three columns, the booking link's bare address as accessibility label, the
  German camera button squeezed into one line by the 3:4 preview at AX5; the rest were test-walk problems at AX5
  (rows taller than the screen in German, a switch under a pinned confirm button, a button under the floating tab
  bar).
- The UI-test seed now gives the profile the `-uiLocale` language (More showed "Esthetician" in every localization).

## 3. Reviewer round trip

Import used to write straight into `Localizable.xcstrings`, which the next merge overwrote, and `translated` could
never survive a merge. Now: export (app + web CSV) → edit → `import-strings.sh <id> <csv> --reviewed` writes the
batches and records approvals (`Config/Locale/reviewed/<id>.json`, fingerprints) → `merge-strings.py` keeps approved
strings `translated` while unchanged. `docs/review/README.md` and one reading-order file per wave-1 language.

## 4. Templates, catalogs, legal

- `docs/strings/message-templates.json`: fourteen localizations × sixteen kinds (the twelve extra kinds of 07 §6),
  same placeholders, polite address to clients.
- Profession catalogs: names fixed (above); `check-professions.sh` unchanged (keys, minutes, follow-ups as English).
- Legal `2026-10-2` for the four documents in use in all fourteen localizations: the facts of D44 to D55; Europe as a
  common GDPR core (Part A) plus national annexes (PT, ES, IT, FR, DE+AT+CH, UK+IE+AU+NZ+ZA), `legal/EUROPE.md`;
  pt-BR written for the LGPD (operador, art. 18, 15 days, ANPD, encarregado, art. 48). Versions are compared as
  numbers now (`check-legal-status.py`, `web/scripts/build-legal.ts`; the app already did). Bundled copies synced.

## 5. Open

- **Help and Privacy describe a per-client "Export her data / Delete her data" under Edit that the Edit screen does
  not have** (`help.topic.deleteClient.answer`, `privacy.perClient.subtitle`). The repository has `deleteClient`; the
  screen does not. A product gap for S12, not a string problem; the strings were left describing the planned flow.
- Text in Arabic and Devanagari is skipped by the clipped-text audit (its heuristic measures fallback fonts with Latin
  metrics); those screens are covered by the screenshots and the title-width test.
- No native reader exists (D41): every non-English string stays `needs_review`.
- **Calendar, found by the smoke run on 2026-10-10 at 11:35 in São Paulo**: on today's day view, a tap on the 09:00
  row (an hour already past) did not open New appointment and the day jumped to Monday 5 October; a tap on 14:00
  opened it. Not caused by S11 (the same with the S10 `FlowLayout`); `CalendarUITests` now taps an hour still ahead
  (`firstTappableSlot`). To investigate in S12 (`DayTimelineView` hour rows, `CalendarHeader`).
