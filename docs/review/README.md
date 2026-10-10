# Native review of the strings (task H10)

Every string Claude Code wrote is `needs_review` (D41: no human review is planned, and Claude Code never promotes a
string). This folder is ready for the day a native reader exists. Wave 1 first (Brazil and Europe):
[pt-BR](pt-BR.md), [pt-PT](pt-PT.md), [es](es.md), [it](it.md), [fr](fr.md), [de](de.md), [en](en.md), [en-GB](en-GB.md).
Each file lists the screens and strings in the order a professional meets them, and the S11 decisions to check first.

## The round trip

1. **Export.** `scripts/export-strings.sh <id>` (or `all`) writes, for one localization:
   - `build/strings-<id>.csv`: every app string (both catalogs, plurals as `key|one`, `key|other`...), with the
     English source, the translator comment and the state;
   - `build/web-strings-<id>.csv`: every booking-page string.
   Columns: `key, en, <id>, comment, state`. Open them in Numbers or Excel; keep UTF-8.
2. **Review.** The reader edits only the `<id>` column, keeps every placeholder (`%@`, `%lld`, `%1$@`, `{name}`) and
   the plural rows, and reads the screens on a phone (Settings > Bello Hub > Language) or the screenshots of
   `LocalizationScreenshotUITests`. Questions about a term go to `docs/strings/glossary.csv` first.
3. **Import.** `scripts/import-strings.sh <id> build/strings-<id>.csv --reviewed` writes the corrections into the
   batch files that own the keys (`Config/Locale/strings/*.json`, `Config/Locale/infoplist/infoplist.json`) and records
   every imported string as approved in `Config/Locale/reviewed/<id>.json` (a fingerprint of the approved text).
   `scripts/import-strings.sh <id> build/web-strings-<id>.csv --web` writes the booking-page corrections into
   `web/src/i18n/<id>.json`. Leave out `--reviewed` to import corrections that still need a second reader.
4. **Rebuild and check.** `python3 scripts/merge-strings.py` rebuilds both catalogs; approved strings become
   `translated` and stay so until their text changes. Then `scripts/check-strings.sh --final` and, for the pages,
   `cd web && npm run i18n`. When a localization is fully approved, remove it from "Strings awaiting reviewers" in
   `docs/PROGRESS.md`; `--final` then fails if any of its strings is still `needs_review`.
5. **Derived localizations.** `es-419` and `en-GB` are never imported: a correction is a line in
   `Config/Locale/overrides/<id>.json` (app) or `web/src/i18n/overrides/<id>.json` (pages), then the merge.

`scripts/test.sh fast` runs `scripts/import-strings.sh --self-test`, which exports, changes and imports on copies
of the batches, so the round trip keeps working.
