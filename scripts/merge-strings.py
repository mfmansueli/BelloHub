#!/usr/bin/env python3
"""Usage: scripts/merge-strings.py [batch.json ...]   (default: every file in Config/Locale/strings/)

Merges authored strings into BelloHub/SupportFiles/Localizable.xcstrings, then re-derives es-419 and
en-GB. A batch file looks like:

  {"languages": ["en", "pt-BR", "pt-PT", "es-MX", "es", "it", "fr", "de", "tr", "id", "hi", "ar"],
   "strings": [["home.title", "comment for the translator", "Home", "Início", ...]]}

Each row is [key, comment, <one value per language, in the order of "languages">]. A value is a string,
or a {"one": ..., "other": ...} object for a plural ({"*": text} repeats one text for every category the language needs). es-419 and en-GB are not written by hand: they come
from their parents plus Config/Locale/overrides/<id>.json (scripts/derive-locales.py).
Every authored value is stored as `needs_review` except the English source (`translated`): no native has
read it, and Claude Code never promotes a string to reviewed (docs/07-LOCALIZATION.md section 1).
"""
import glob
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402


def merge(batch_path, catalog):
    with open(batch_path, encoding="utf-8") as handle:
        batch = json.load(handle)
    languages = batch["languages"]
    unknown = [lang for lang in languages if lang not in lib.AUTHORED]
    if unknown:
        sys.exit(f"{batch_path}: unknown or derived languages {unknown}; allowed {lib.AUTHORED}")
    missing = [lang for lang in lib.AUTHORED if lang not in languages]
    if missing:
        sys.exit(f"{batch_path}: missing languages {missing}")
    count = 0
    for row in batch["strings"]:
        key, comment, values = row[0], row[1], row[2:]
        if len(values) != len(languages):
            sys.exit(f"{batch_path}: {key} has {len(values)} values for {len(languages)} languages")
        entry = {"extractionState": "manual", "localizations": {}}
        if comment:
            entry["comment"] = comment
        for language, value in zip(languages, values):
            state = "translated" if language == lib.SOURCE_LANGUAGE else "needs_review"
            if isinstance(value, dict) and "*" in value:
                # {"*": text}: the same text for every plural category the language needs.
                value = {category: value["*"] for category in sorted(lib.plural_required(language))}
            entry["localizations"][language] = lib.localization_entry(value, state)
        catalog["strings"][key] = entry
        count += 1
    return count


def main():
    paths = sys.argv[1:] or sorted(glob.glob(os.path.join(lib.BATCH_DIR, "*.json")))
    catalog = lib.load_catalog()
    catalog["sourceLanguage"] = lib.SOURCE_LANGUAGE
    total = sum(merge(path, catalog) for path in paths)
    lib.save_catalog(catalog)
    print(f"Merged {total} strings from {len(paths)} batch file(s)")
    subprocess.check_call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "derive-locales.py")])


if __name__ == "__main__":
    main()
