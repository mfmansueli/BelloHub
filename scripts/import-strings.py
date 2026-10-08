#!/usr/bin/env python3
"""Imports reviewer corrections from a CSV produced by export-strings.sh."""
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    reviewed = "--reviewed" in sys.argv
    if len(args) != 2:
        sys.exit("usage: import-strings.sh <localization> <file.csv> [--reviewed]")
    language, path = args
    if language in lib.DERIVED:
        sys.exit(f"{language} is derived from {lib.DERIVED[language]}; edit the parent or its override file")
    if language not in lib.LOCALIZATIONS:
        sys.exit(f"unknown localization {language}")
    catalog = lib.load_catalog()
    changed = 0
    with open(path, encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            key, _, category = row["key"].partition("|")
            entry = catalog["strings"].get(key)
            if entry is None:
                print(f"warning: unknown key {key}, skipped", file=sys.stderr)
                continue
            localization = entry["localizations"].get(language)
            values = lib.entry_values(localization)
            current = values.get(category or None)
            new = row[language]
            if current is None or new == current:
                continue
            state = "translated" if reviewed else "needs_review"
            if category:
                entry["localizations"][language]["variations"]["plural"][category] = lib.unit(new, state)
            else:
                entry["localizations"][language] = lib.unit(new, state)
            changed += 1
    lib.save_catalog(catalog)
    print(f"Imported {changed} change(s) into {language}")


if __name__ == "__main__":
    main()
