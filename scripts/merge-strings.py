#!/usr/bin/env python3
"""Usage: scripts/merge-strings.py [--prune] [batch.json ...]   (default: every file in Config/Locale/strings/)

Merges authored strings into BelloHub/SupportFiles/Localizable.xcstrings, then re-derives es-419 and
en-GB. With --prune (only when every batch is merged) it also removes catalog keys that no batch
authors any more and no Swift file under BelloHub/ names, so a key deleted from a batch leaves the
catalog too; an unauthored key that code still uses is kept and reported. A batch file looks like:

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
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402

IDENTIFIER = re.compile(r'accessibilityIdentifier\(\s*"[^"]*"')


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


def prune_auto_extracted(catalog):
    """Drops the entries an Xcode build adds on its own: with SWIFT_EMIT_LOC_STRINGS, a `defaultValue:` literal or an
    Info.plist key is extracted as a key with an English value only. Every authored key is `manual` (batches own the
    Localizable catalog; InfoPlist.xcstrings is written by hand), so a non-manual entry is noise that only breaks
    check-strings.sh."""
    stale = [key for key, entry in catalog["strings"].items() if entry.get("extractionState") != "manual"]
    for key in stale:
        del catalog["strings"][key]
    return len(stale)


def authored_keys(paths):
    keys = set()
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            keys.update(row[0] for row in json.load(handle)["strings"])
    return keys


def duplicate_keys(paths):
    """Keys that two batches both author; one key has exactly one owner (CLAUDE.md section 3)."""
    seen, duplicates = set(), []
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            for row in json.load(handle)["strings"]:
                if row[0] in seen:
                    duplicates.append(row[0])
                seen.add(row[0])
    return sorted(duplicates)


def source_text():
    """Every Swift file of the app target, joined, to see whether a key is still named in code. Accessibility
    identifiers often share a key's name ("clients.count") and are not a use of the key, so they are left out."""
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "BelloHub")
    parts = []
    for folder, _, names in os.walk(root):
        for name in names:
            if name.endswith(".swift"):
                with open(os.path.join(folder, name), encoding="utf-8") as handle:
                    parts.append(handle.read())
    return IDENTIFIER.sub("", "\n".join(parts))


def prune_unauthored(catalog, paths):
    """Removes keys no batch authors and no Swift file names; returns how many went."""
    keep = authored_keys(paths)
    code = source_text()
    removed = 0
    for key in [key for key in catalog["strings"] if key not in keep]:
        if f'"{key}"' in code:
            print(f"warning: {key} is used in code but no batch authors it; kept", file=sys.stderr)
            continue
        del catalog["strings"][key]
        removed += 1
    return removed


def main():
    arguments = sys.argv[1:]
    prune = "--prune" in arguments
    paths = [arg for arg in arguments if arg != "--prune"]
    if prune and paths:
        sys.exit("--prune only makes sense when every batch is merged (pass no batch paths)")
    paths = paths or sorted(glob.glob(os.path.join(lib.BATCH_DIR, "*.json")))
    duplicates = duplicate_keys(paths)
    if duplicates:
        sys.exit("keys authored by more than one batch (the later file would silently win): " + ", ".join(duplicates))
    catalog = lib.load_catalog()
    catalog["sourceLanguage"] = lib.SOURCE_LANGUAGE
    pruned = prune_auto_extracted(catalog)
    if pruned:
        print(f"Dropped {pruned} auto-extracted key(s) from Localizable.xcstrings")
    infoplist = lib.load_catalog(lib.INFOPLIST_CATALOG)
    pruned = prune_auto_extracted(infoplist)
    if pruned:
        lib.save_catalog(infoplist, lib.INFOPLIST_CATALOG)
        print(f"Dropped {pruned} auto-extracted key(s) from InfoPlist.xcstrings")
    total = sum(merge(path, catalog) for path in paths)
    removed = prune_unauthored(catalog, paths) if prune else 0
    lib.save_catalog(catalog)
    print(f"Merged {total} strings from {len(paths)} batch file(s)" + (f", removed {removed}" if prune else ""))
    subprocess.check_call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "derive-locales.py")])


if __name__ == "__main__":
    main()
