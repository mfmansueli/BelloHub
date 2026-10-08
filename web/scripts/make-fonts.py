#!/usr/bin/env python3
"""Builds the self-hosted web fonts from the variable fonts the iOS app bundles (one source).

    web/scripts/.venv/bin/python web/scripts/make-fonts.py

Output (committed, re-run only when the source fonts change): web/public/fonts/*.woff2

- DM Sans: variable weight 400 to 600 (the interface uses 400 and 600), optical size pinned.
- Fraunces: static weight 500 (headings and numerals only), optical size pinned near display sizes.
- Subset to Basic Latin, Latin-1, Latin Extended-A (Turkish, Romanian), a few Latin Extended-B letters
  and the currency symbols the pages show (EUR, GBP, TRY, INR, BRL uses ASCII "R$").
- Arabic and Devanagari are NOT included: they use the system font stacks (docs/10 section 1).
"""
from __future__ import annotations

import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "BelloHub" / "DesignSystem" / "Fonts"
OUT = ROOT / "web" / "public" / "fonts"

UNICODES = (
    list(range(0x0020, 0x007F))  # Basic Latin
    + list(range(0x00A0, 0x0100))  # Latin-1 Supplement
    + list(range(0x0100, 0x0180))  # Latin Extended-A
    + [0x0218, 0x0219, 0x021A, 0x021B]  # Romanian comma-below
    + [0x02BB, 0x02BC, 0x02C6, 0x02DA, 0x02DC]  # modifier letters used in transliteration
    + list(range(0x2010, 0x2028))  # dashes, quotes, bullets, ellipsis
    + [0x202F, 0x2039, 0x203A, 0x2044, 0x2060]
    + [0x20AC, 0x20BA, 0x20B9, 0x20A3, 0x20BD, 0x2116, 0x2122, 0x2212, 0x2215]  # currency, trademark, minus
    + [0x2190, 0x2191, 0x2192, 0x2193, 0x00B7]  # arrows, middle dot
    + [0xFEFF, 0xFFFD]
)


def build(source: str, target: str, limits: dict[str, float | tuple[float, float]]) -> None:
    font = TTFont(SOURCE / source)
    font = instancer.instantiateVariableFont(font, limits)
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = ["kern", "liga", "calt", "ccmp", "locl", "mark", "mkmk", "tnum", "lnum", "case", "ss01"]
    options.notdef_outline = True
    options.name_IDs = [1, 2, 3, 4, 6]
    options.drop_tables += ["DSIG"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=UNICODES)
    subsetter.subset(font)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / target
    font.flavor = "woff2"
    font.save(path)
    print(f"{target}: {path.stat().st_size} bytes")


def main() -> int:
    if not SOURCE.exists():
        print(f"error: {SOURCE} not found (run from the repository)", file=sys.stderr)
        return 1
    axes_dm = TTFont(SOURCE / "DMSans-VF.ttf")["fvar"].axes
    axes_fr = TTFont(SOURCE / "Fraunces-VF.ttf")["fvar"].axes
    print("DM Sans axes:", [(a.axisTag, a.minValue, a.defaultValue, a.maxValue) for a in axes_dm])
    print("Fraunces axes:", [(a.axisTag, a.minValue, a.defaultValue, a.maxValue) for a in axes_fr])
    dm_limits: dict[str, float | tuple[float, float]] = {}
    for axis in axes_dm:
        if axis.axisTag == "wght":
            dm_limits["wght"] = (400.0, 600.0)
        else:
            dm_limits[axis.axisTag] = min(max(14.0, axis.minValue), axis.maxValue) if axis.axisTag == "opsz" else axis.defaultValue
    fr_limits: dict[str, float | tuple[float, float]] = {}
    for axis in axes_fr:
        if axis.axisTag == "wght":
            fr_limits["wght"] = 500.0
        elif axis.axisTag == "opsz":
            fr_limits["opsz"] = min(max(36.0, axis.minValue), axis.maxValue)
        else:
            fr_limits[axis.axisTag] = axis.defaultValue
    build("DMSans-VF.ttf", "dm-sans-latin.woff2", dm_limits)
    build("Fraunces-VF.ttf", "fraunces-500-latin.woff2", fr_limits)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
