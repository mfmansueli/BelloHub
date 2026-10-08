#!/usr/bin/env python3
"""Usage: scripts/derive-locales.py [--check]

Rewrites the derived localizations (es-419 from es-MX, en-GB from en) in the catalog from their parents
plus the small override files in Config/Locale/overrides/<id>.json. A key missing from the override file
means "same as the parent". Every derived value is stored as `needs_review`.
With --check it changes nothing and exits 1 when a derived localization is out of date
(scripts/check-strings.sh uses this).

An override file maps a key to a string, or to a {category: string} object for a plural.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stringslib as lib  # noqa: E402


def derived_entry(parent_localization, override):
    """The derived localization: the override if present, otherwise a copy of the parent, as needs_review."""
    if override is not None:
        return lib.localization_entry(override, "needs_review")
    if parent_localization is None:
        return None
    if "stringUnit" in parent_localization:
        return lib.unit(parent_localization["stringUnit"]["value"], "needs_review")
    plural = parent_localization["variations"]["plural"]
    return {"variations": {"plural": {cat: lib.unit(sub["stringUnit"]["value"], "needs_review")
                                      for cat, sub in plural.items()}}}


def derive(catalog):
    stale = []
    for derived, parent in lib.DERIVED.items():
        overrides = lib.load_overrides(derived)
        for key, entry in catalog["strings"].items():
            localizations = entry.setdefault("localizations", {})
            wanted = derived_entry(localizations.get(parent), overrides.get(key))
            if wanted is None:
                continue
            if localizations.get(derived) != wanted:
                stale.append((derived, key))
                localizations[derived] = wanted
    return stale


def main():
    check_only = "--check" in sys.argv
    catalog = lib.load_catalog()
    stale = derive(catalog)
    if check_only:
        for language, key in stale:
            print(f"error: {language} is out of date for {key}; run scripts/derive-locales.py", file=sys.stderr)
        sys.exit(1 if stale else 0)
    lib.save_catalog(catalog)
    print(f"Derived es-419 and en-GB ({len(stale)} entries updated)")


if __name__ == "__main__":
    main()
