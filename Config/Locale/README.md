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
- `infoplist/*.json`: the permission texts and the display name, same format, merged into
  `BelloHub/SupportFiles/InfoPlist.xcstrings` (S11: neither catalog is edited by hand).
- `reviewed/<id>.json`: strings a native reader approved (`scripts/import-strings.sh <id> <file.csv> --reviewed`), as
  key -> fingerprint of the approved text; the merge keeps them `translated` while the text is unchanged.
- `python3 scripts/merge-strings.py` merges every batch into the catalogs and re-derives `es-419` and `en-GB`
  (add `--prune` after deleting keys). A key may be authored by one batch only.
  It stores every non-English value as `needs_review`: no native has read it, and only a human promotes a
  string to `translated` (`scripts/import-strings.sh <id> <file.csv> --reviewed`).
- `scripts/check-strings.sh --final` is the gate (it runs inside `scripts/test.sh fast`): completeness, plurals,
  placeholders, derived localizations, the S11 style rules (address per audience, regional words, gender slashes,
  Arabic punctuation, US/UK spelling, the same rules on the booking pages), the glossary and message templates, and the
  navigation-title lists. `scripts/export-strings.sh <id|all>` and `scripts/import-strings.sh` are the reviewer round
  trip (`docs/review/README.md`).

Strings with arguments keep the semantic key and carry the interpolation in the default value:
`LocalizedStringResource("catalog.sample.greeting", defaultValue: "Good morning, \(name)")`.
`Text("key \(arg)")` would look up the key `key %@`, which does not exist.
