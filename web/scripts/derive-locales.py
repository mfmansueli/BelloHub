#!/usr/bin/env python3
"""Derives the two localizations nobody writes by hand, exactly like the iOS catalog does (docs/07 section 2.3).

    python3 scripts/derive-locales.py            rewrites src/i18n/es-419.json and src/i18n/en-GB.json
    python3 scripts/derive-locales.py --check    fails when either is out of date

`es-419` is `es-MX` plus the overrides of src/i18n/overrides/es-419.json; `en-GB` is `en` plus
src/i18n/overrides/en-GB.json. A key missing from an override file means "same as the parent". Keep the override
files small. Standard library only (Python 3.9+).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

I18N = Path(__file__).resolve().parent.parent / "src" / "i18n"
DERIVED = {"es-419": "es-MX", "en-GB": "en"}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def derive(child: str, parent: str) -> dict:
    base = load(I18N / f"{parent}.json")
    overrides_path = I18N / "overrides" / f"{child}.json"
    overrides = load(overrides_path) if overrides_path.exists() else {}
    unknown = sorted(set(overrides) - set(base))
    if unknown:
        raise SystemExit(f"error: {overrides_path.name} overrides keys the parent {parent} does not have: {', '.join(unknown)}")
    return {key: overrides.get(key, value) for key, value in base.items()}


def render(document: dict) -> str:
    return json.dumps(document, ensure_ascii=False, indent=2) + "\n"


def main(argv: list[str]) -> int:
    check = "--check" in argv
    stale: list[str] = []
    for child, parent in DERIVED.items():
        expected = derive(child, parent)
        target = I18N / f"{child}.json"
        current = load(target) if target.exists() else None
        if current != expected:
            stale.append(child)
            if not check:
                target.write_text(render(expected), encoding="utf-8")
    if check and stale:
        print(f"error: derived localization out of date: {', '.join(stale)}. Run: python3 scripts/derive-locales.py", file=sys.stderr)
        return 1
    print("derived localizations are up to date" if check or not stale else f"rewrote {', '.join(stale)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
