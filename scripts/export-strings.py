#!/usr/bin/env python3
"""Exports a localization (or all) for human reviewers (docs/review/README.md):
- build/strings-<id>.csv, the app (Localizable and InfoPlist catalogs): key, en, <localization>, comment, state;
- build/web-strings-<id>.csv, the booking pages (web/src/i18n): key, en, <localization>, comment, state.
Plural entries are exported one row per category as `key|one`, `key|other`, ... Read back with import-strings.sh."""
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402


def rows_for(catalog, language):
    for key, entry in sorted(catalog["strings"].items()):
        localizations = entry.get("localizations", {})
        english = lib.entry_values(localizations.get(lib.SOURCE_LANGUAGE))
        target = lib.entry_values(localizations.get(language))
        state = lib.entry_state(localizations.get(language)) or "missing"
        for category in sorted(target, key=lambda c: (c is not None, c)):
            label = key if category is None else f"{key}|{category}"
            yield [label, english.get(category) or english.get("other", ""), target[category],
                   entry.get("comment", ""), state]


def web_rows(language):
    import json
    folder = os.path.join(lib.ROOT, "web", "src", "i18n")
    english = json.load(open(os.path.join(folder, "en.json"), encoding="utf-8"))
    target = json.load(open(os.path.join(folder, language + ".json"), encoding="utf-8"))
    for key, value in english.items():
        mine = target.get(key)
        if isinstance(mine, dict):
            for category, text in mine.items():
                source = value.get(category) or value.get("other", "") if isinstance(value, dict) else value
                yield [f"{key}|{category}", source, text, "", "needs_review"]
        elif mine is not None:
            yield [key, value if isinstance(value, str) else "", mine, "", "needs_review"]


def main():
    wanted = sys.argv[1] if len(sys.argv) > 1 else "all"
    languages = lib.LOCALIZATIONS if wanted == "all" else [wanted]
    unknown = [lang for lang in languages if lang not in lib.LOCALIZATIONS]
    if unknown:
        sys.exit(f"unknown localization {unknown}; choose from {lib.LOCALIZATIONS}")
    catalog = lib.load_catalog()
    os.makedirs(os.path.join(lib.ROOT, "build"), exist_ok=True)
    for language in languages:
        path = os.path.join(lib.ROOT, "build", f"strings-{language}.csv")
        with open(path, "w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["key", "en", language, "comment", "state"])
            writer.writerows(rows_for(catalog, language))
            if os.path.exists(lib.INFOPLIST_CATALOG):
                writer.writerows(rows_for(lib.load_catalog(lib.INFOPLIST_CATALOG), language))
        web = os.path.join(lib.ROOT, "build", f"web-strings-{language}.csv")
        with open(web, "w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["key", "en", language, "comment", "state"])
            writer.writerows(web_rows(language))
        print(f"Wrote build/strings-{language}.csv and build/web-strings-{language}.csv")


if __name__ == "__main__":
    main()
