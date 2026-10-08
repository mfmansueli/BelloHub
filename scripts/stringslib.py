"""Shared helpers for the string-catalog scripts (Python 3, standard library only).

The catalog is `BelloHub/SupportFiles/Localizable.xcstrings`. Strings are authored in batch files under
`Config/Locale/strings/*.json` and merged into the catalog by `scripts/merge-strings.py`.
"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CATALOG = os.path.join(ROOT, "BelloHub", "SupportFiles", "Localizable.xcstrings")
INFOPLIST_CATALOG = os.path.join(ROOT, "BelloHub", "SupportFiles", "InfoPlist.xcstrings")
OVERRIDES_DIR = os.path.join(ROOT, "Config", "Locale", "overrides")
BATCH_DIR = os.path.join(ROOT, "Config", "Locale", "strings")

SOURCE_LANGUAGE = "en"
# The fourteen localizations (docs/07-LOCALIZATION.md section 1).
LOCALIZATIONS = ["pt-BR", "pt-PT", "es-MX", "es-419", "es", "en", "en-GB", "it", "fr", "de", "tr", "id", "hi", "ar"]
# Derived localizations and their parent. Everything else is written natively.
DERIVED = {"es-419": "es-MX", "en-GB": "en"}
# Languages written natively, in the order batch files list them.
AUTHORED = [code for code in LOCALIZATIONS if code not in DERIVED]

# CLDR plural categories each language must provide (docs/07-LOCALIZATION.md section 2.1).
PLURAL_REQUIRED = {
    "ar": {"zero", "one", "two", "few", "many", "other"},
    "id": {"other"},
}
PLURAL_DEFAULT = {"one", "other"}

PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:l{0,2}[dDuUxX]|@|[fFeEgG]|\.\d+f)|\{[A-Za-z]+\}")


def plural_required(language):
    return PLURAL_REQUIRED.get(language, PLURAL_DEFAULT)


def load_catalog(path=CATALOG):
    if not os.path.exists(path):
        return {"sourceLanguage": SOURCE_LANGUAGE, "strings": {}, "version": "1.0"}
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def save_catalog(catalog, path=CATALOG):
    # Xcode writes keys sorted and uses " : " as the separator; matching it keeps diffs small.
    text = json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text + "\n")


def unit(value, state):
    return {"stringUnit": {"state": state, "value": value}}


def localization_entry(value, state):
    """A catalog localization from a plain string or a {category: string} plural dict."""
    if isinstance(value, dict):
        return {"variations": {"plural": {cat: unit(text, state) for cat, text in value.items()}}}
    return unit(value, state)


def entry_values(localization):
    """All string values of a catalog localization, as a {category-or-None: text} dict."""
    if localization is None:
        return {}
    if "stringUnit" in localization:
        return {None: localization["stringUnit"].get("value", "")}
    plural = localization.get("variations", {}).get("plural", {})
    return {cat: sub.get("stringUnit", {}).get("value", "") for cat, sub in plural.items()}


def entry_state(localization):
    if localization is None:
        return None
    if "stringUnit" in localization:
        return localization["stringUnit"].get("state")
    plural = localization.get("variations", {}).get("plural", {})
    states = {sub.get("stringUnit", {}).get("state") for sub in plural.values()}
    return states.pop() if len(states) == 1 else "needs_review"


def placeholders(text):
    return sorted(PLACEHOLDER.findall(text))


def load_overrides(language):
    path = os.path.join(OVERRIDES_DIR, language + ".json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)
