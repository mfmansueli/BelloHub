# Locale sources

How strings get into the app (docs/07-LOCALIZATION.md). The committed catalog is
`BelloHub/SupportFiles/Localizable.xcstrings`; these files are how it is written.

- `strings/<stage>-<feature>.json`: a batch of strings authored in the twelve native languages
  (`en, pt-BR, pt-PT, es-MX, es, it, fr, de, tr, id, hi, ar`). Each row is
  `[key, comment, <one value per language in the batch's "languages" order>]`. A value is a string, or
  `{"one": ..., "other": ...}` for a plural, or `{"*": text}` to repeat one text for every plural category the
  language needs (Arabic has six). Keys are semantic (`home.nextUp.title`), never the English sentence.
- `overrides/es-419.json` and `overrides/en-GB.json`: the only hand-written part of the two derived
  localizations. A key that is missing means "same as the parent" (`es-MX` and `en`).
- `python3 scripts/merge-strings.py` merges every batch into the catalog and re-derives `es-419` and `en-GB`.
  It stores every non-English value as `needs_review`: no native has read it, and only a human promotes a
  string to `translated` (`scripts/import-strings.sh <id> <file.csv> --reviewed`).
- `scripts/check-strings.sh` is the gate (it runs inside `scripts/test.sh fast`); `scripts/export-strings.sh
  <id|all>` writes `build/strings-<id>.csv` for reviewers.

Strings with arguments keep the semantic key and carry the interpolation in the default value:
`LocalizedStringResource("catalog.sample.greeting", defaultValue: "Good morning, \(name)")`.
`Text("key \(arg)")` would look up the key `key %@`, which does not exist.
