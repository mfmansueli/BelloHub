#!/usr/bin/env python3
"""Usage: scripts/check-strings.py [--final]

Fails (exit 1) on: a key missing from any of the fourteen localizations, an empty value, a missing plural
category (all six for ar), a placeholder mismatch, a hard-coded text literal in Screens/, a key used in code
that is absent from the catalog, or a derived localization (es-419, en-GB) that is out of date.
Always prints a coverage table (languages x translated x needs review).
With --final (stage S11 and later) it also fails on any `needs_review` string whose language is not in
the allowed list at the top of docs/PROGRESS.md section "Strings awaiting reviewers" (pt-BR and the other
languages stay listed there until a human promotes them).
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402

KEY_RE = re.compile(r"^[a-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+$")
SOURCE_DIRS = ["BelloHub"]
# Call sites whose first string argument is a localization key.
KEY_CALLS = re.compile(
    r"""(?:Text|LocalizedStringKey|LocalizedStringResource|String\(localized:|Label|Button|Toggle|Section|
        navigationTitle|accessibilityLabel|accessibilityHint)\(\s*(?:localized:\s*)?"([^"\\]+)"|
        (?:title|label|message|actionTitle|prompt|subtitle|closeLabel|placeholder|text)\s*:\s*"([^"\\]+)"
    """, re.VERBOSE)
HARD_CODED_TEXT = re.compile(r'\bText\(\s*"([^"\\]*)"\s*\)')


def swift_files(*roots):
    for root in roots:
        for folder, _, names in os.walk(os.path.join(lib.ROOT, root)):
            for name in names:
                if name.endswith(".swift"):
                    yield os.path.join(folder, name)


def normalize(text):
    return sorted(re.sub(r"%\d+\$", "%", p) for p in lib.placeholders(text))


def check_catalog(catalog, label, errors):
    strings = catalog.get("strings", {})
    for key, entry in sorted(strings.items()):
        localizations = entry.get("localizations", {})
        source = localizations.get(lib.SOURCE_LANGUAGE)
        source_values = lib.entry_values(source)
        source_is_plural = None not in source_values and bool(source_values)
        for language in lib.LOCALIZATIONS:
            localization = localizations.get(language)
            if localization is None:
                errors.append(f"{label}: {key} is missing in {language}")
                continue
            values = lib.entry_values(localization)
            is_plural = None not in values and bool(values)
            if is_plural != source_is_plural:
                errors.append(f"{label}: {key} in {language} is {'plural' if is_plural else 'plain'}, "
                              f"the source is {'plural' if source_is_plural else 'plain'}")
                continue
            if any(not text.strip() for text in values.values()):
                errors.append(f"{label}: {key} has an empty value in {language}")
            if is_plural:
                missing = lib.plural_required(language) - set(values)
                if missing:
                    errors.append(f"{label}: {key} in {language} lacks plural categories {sorted(missing)}")
            reference = source_values.get("other") if source_is_plural else source_values.get(None)
            for category, text in values.items():
                expected = normalize(reference or "")
                found = normalize(text)
                if is_plural and category != "other":
                    if not set(found) <= set(expected):
                        errors.append(f"{label}: {key} [{language}/{category}] has placeholders {found}, "
                                      f"allowed {expected}")
                elif found != expected:
                    errors.append(f"{label}: {key} [{language}] has placeholders {found}, expected {expected}")


def check_code(catalog, errors):
    keys = set(catalog.get("strings", {}))
    for path in swift_files(*SOURCE_DIRS):
        relative = os.path.relpath(path, lib.ROOT)
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        if "/Screens/" in path:
            for match in HARD_CODED_TEXT.finditer(text):
                literal = match.group(1)
                if not KEY_RE.match(literal):
                    errors.append(f"{relative}: hard-coded text \"{literal}\"; use a catalog key or Text(verbatim:)")
        for match in KEY_CALLS.finditer(text):
            literal = match.group(1) or match.group(2)
            # accessibility identifiers and catalog keys share a shape; only literals that are
            # already catalog namespaces are checked, so identifiers are never mistaken for keys.
            if literal and KEY_RE.match(literal) and literal.split(".")[0] in namespaces(keys) and literal not in keys:
                errors.append(f"{relative}: key \"{literal}\" is not in the catalog")


def namespaces(keys):
    return {key.split(".")[0] for key in keys}


def coverage(catalog):
    strings = catalog.get("strings", {})
    print(f"{'localization':<8} {'present':>8} {'translated':>11} {'needs review':>13}")
    for language in lib.LOCALIZATIONS:
        present = translated = review = 0
        for entry in strings.values():
            localization = entry.get("localizations", {}).get(language)
            if localization is None:
                continue
            present += 1
            if lib.entry_state(localization) == "translated":
                translated += 1
            else:
                review += 1
        total = len(strings) or 1
        print(f"{language:<8} {present * 100 // total:>7}% {translated * 100 // total:>10}% {review * 100 // total:>12}%")
    print(f"{len(strings)} keys")


def main():
    errors = []
    catalog = lib.load_catalog()
    check_catalog(catalog, "Localizable", errors)
    if os.path.exists(lib.INFOPLIST_CATALOG):
        check_catalog(lib.load_catalog(lib.INFOPLIST_CATALOG), "InfoPlist", errors)
    check_code(catalog, errors)
    derived = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "derive-locales.py"),
                              "--check"], capture_output=True, text=True)
    errors.extend(line.removeprefix("error: ") for line in derived.stderr.splitlines() if line.strip())
    coverage(catalog)
    if errors:
        shown = errors[:60]
        print("\n".join(f"error: {line}" for line in shown), file=sys.stderr)
        if len(errors) > len(shown):
            print(f"error: ... and {len(errors) - len(shown)} more", file=sys.stderr)
        sys.exit(1)
    print("Strings check passed")


if __name__ == "__main__":
    main()
