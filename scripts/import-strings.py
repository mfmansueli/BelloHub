#!/usr/bin/env python3
"""Usage: scripts/import-strings.py <localization> <file.csv> [--reviewed] [--web]
       scripts/import-strings.py --self-test

Reads a reviewer's corrections from a CSV made by export-strings.sh (columns key, en, <localization>, comment, state)
and writes them where strings are authored, never into the catalogs by hand (docs/07-LOCALIZATION.md section 9):
- app strings go into the batch that owns the key (Config/Locale/strings/*.json, or Config/Locale/infoplist/*.json);
  then run scripts/merge-strings.py, which rebuilds both catalogs and the derived localizations;
- with --web the file is a booking-page export (build/web-strings-<id>.csv) and goes into web/src/i18n/<id>.json.
With --reviewed (a human who read the language passes it) every imported app string, changed or not, is recorded in
Config/Locale/reviewed/<localization>.json with a fingerprint of its text; merge-strings.py then stores it as
`translated` for as long as the text stays the same. Without it, changes stay `needs_review`.
Derived localizations (es-419, en-GB) cannot be imported: edit the parent or Config/Locale/overrides/<id>.json.
--self-test runs the export, change and import round trip on copies in a temporary folder (scripts/test.sh fast).
"""
import csv
import glob
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402


def batch_paths():
    return sorted(glob.glob(os.path.join(lib.BATCH_DIR, "*.json"))) + \
        sorted(glob.glob(os.path.join(lib.INFOPLIST_BATCH_DIR, "*.json")))


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")


def import_app(language, rows, reviewed):
    """Writes the rows into the batches; returns (changed, recorded as reviewed)."""
    batches = {path: json.load(open(path, encoding="utf-8")) for path in batch_paths()}
    owner = {row[0]: (path, index) for path, batch in batches.items() for index, row in enumerate(batch["strings"])}
    touched, changed, approved = set(), 0, {}
    for row in rows:
        key, _, category = row["key"].partition("|")
        if key not in owner:
            print(f"warning: unknown key {key}, skipped", file=sys.stderr)
            continue
        path, index = owner[key]
        batch = batches[path]
        column = 2 + batch["languages"].index(language)
        value = batch["strings"][index][column]
        new = row[language]
        if category:
            if isinstance(value, dict) and "*" in value:
                value = {name: value["*"] for name in sorted(lib.plural_required(language))}
            if not isinstance(value, dict) or category not in value:
                print(f"warning: {key} has no plural category {category} in {language}, skipped", file=sys.stderr)
                continue
            if value[category] != new:
                value = dict(value, **{category: new})
                changed += 1
        elif value != new:
            value = new
            changed += 1
        if batch["strings"][index][column] != value:
            batch["strings"][index][column] = value
            touched.add(path)
        approved[key] = lib.fingerprint(value)
    for path in touched:
        write_json(path, batches[path])
    if reviewed:
        path = os.path.join(lib.REVIEWED_DIR, language + ".json")
        os.makedirs(lib.REVIEWED_DIR, exist_ok=True)
        current = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        current.update(approved)
        write_json(path, dict(sorted(current.items())))
    return changed, len(approved) if reviewed else 0


def import_web(language, rows):
    path = os.path.join(lib.ROOT, "web", "src", "i18n", language + ".json")
    values = json.load(open(path, encoding="utf-8"))
    changed = 0
    for row in rows:
        key, _, category = row["key"].partition("|")
        if key not in values:
            print(f"warning: unknown web key {key}, skipped", file=sys.stderr)
            continue
        if category and isinstance(values[key], dict) and values[key].get(category) != row[language]:
            values[key][category] = row[language]
            changed += 1
        elif not category and values[key] != row[language]:
            values[key] = row[language]
            changed += 1
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(values, ensure_ascii=False, indent=2) + "\n")
    return changed


def read_rows(path):
    with open(path, encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def self_test():
    """Export pt-PT, change one string and one plural form, import with --reviewed: the batches carry the new text,
    the reviewed file has their fingerprints, and an unchanged import changes nothing."""
    import importlib.util
    folder = tempfile.mkdtemp()
    try:
        for name in ("strings", "infoplist"):
            shutil.copytree(os.path.join(lib.ROOT, "Config", "Locale", name), os.path.join(folder, name))
        lib.BATCH_DIR = os.path.join(folder, "strings")
        lib.INFOPLIST_BATCH_DIR = os.path.join(folder, "infoplist")
        lib.REVIEWED_DIR = os.path.join(folder, "reviewed")
        spec = importlib.util.spec_from_file_location("export", os.path.join(lib.ROOT, "scripts", "export-strings.py"))
        export = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(export)
        rows = [dict(zip(["key", "en", "pt-PT", "comment", "state"], row))
                for row in export.rows_for(lib.load_catalog(), "pt-PT")]
        assert import_app("pt-PT", rows, reviewed=False) == (0, 0), "an unchanged export must import as no change"
        single = next(row for row in rows if row["key"] == "common.close")
        plural = next(row for row in rows if row["key"] == "tags.row.count|other")
        single["pt-PT"], plural["pt-PT"] = "Fechar já", "%lld pessoas ao todo"
        changed, approved = import_app("pt-PT", [single, plural], reviewed=True)
        assert (changed, approved) == (2, 2), (changed, approved)
        batches = {row[0]: (row, batch["languages"]) for path in batch_paths()
                   for batch in [json.load(open(path, encoding="utf-8"))] for row in batch["strings"]}
        row, languages = batches["common.close"]
        assert row[2 + languages.index("pt-PT")] == "Fechar já"
        row, languages = batches["tags.row.count"]
        assert row[2 + languages.index("pt-PT")]["other"] == "%lld pessoas ao todo"
        reviewed = json.load(open(os.path.join(lib.REVIEWED_DIR, "pt-PT.json"), encoding="utf-8"))
        assert reviewed["common.close"] == lib.fingerprint("Fechar já")
        print("import-strings round trip: ok")
    finally:
        shutil.rmtree(folder)


def main():
    if "--self-test" in sys.argv:
        self_test()
        return
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        sys.exit("usage: import-strings.sh <localization> <file.csv> [--reviewed] [--web]")
    language, path = args
    if language in lib.DERIVED:
        sys.exit(f"{language} is derived from {lib.DERIVED[language]}; edit the parent or its override file")
    if language not in lib.LOCALIZATIONS:
        sys.exit(f"unknown localization {language}")
    rows = read_rows(path)
    if "--web" in sys.argv:
        print(f"Imported {import_web(language, rows)} change(s) into web/src/i18n/{language}.json")
        return
    changed, approved = import_app(language, rows, "--reviewed" in sys.argv)
    print(f"Imported {changed} change(s) into the {language} batches" +
          (f"; {approved} strings recorded as reviewed" if approved else "") +
          ". Run python3 scripts/merge-strings.py next.")


if __name__ == "__main__":
    main()
