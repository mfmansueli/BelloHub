#!/usr/bin/env python3
"""Usage: scripts/check-professions.py

Checks the profession catalogs in BelloHub/Resources/Professions (docs/07-LOCALIZATION.md section 5): all fourteen
localizations exist, every profession is present in the same order, every localization has the same keys, every name
is filled, keys are unique within each kind (services, tags, fields), and every profession preselects at least one service and one record field.
Quick answers (a field's `tags`, a profession's `reactionTags` and `aftercareTags`) come in the same number as in English,
each filled, at most 32 characters and once per list (spaces and letter case aside).
Structure (minutes, follow-up weeks, defaults, colors) must match the English file so a translation cannot change
behavior. When a language genuinely needs different services (henna brows in `hi`, threading), relax the key check
for that language here and say why in the commit.
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DIR = os.path.join(ROOT, "BelloHub", "Resources", "Professions")
LOCALIZATIONS = ["pt-BR", "pt-PT", "es-MX", "es-419", "es", "en", "en-GB", "it", "fr", "de", "tr", "id", "hi", "ar"]
PROFESSIONS = ["esthetician", "hair", "lash", "nail", "makeup", "tattoo", "barber", "massage", "other"]
COLORS = {"rose", "sage", "peach", "sand"}
INTAKE = {"healthHistory", "consentForm", "patchTestLog"}


def load(code):
    path = os.path.join(DIR, f"professions-{code}.json")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def shape(data):
    """Everything that must not change between languages."""
    return [
        (
            p["id"],
            [(s["key"], s["minutes"], s["followUpWeeks"], s["selected"], s["photos"]) for s in p["services"]],
            [(t["key"], t["color"], t["selected"]) for t in p["tags"]],
            [(f["key"], f["on"], len(f.get("tags", []))) for f in p["fields"]],
            p["intake"],
            len(p.get("reactionTags", [])),
            len(p.get("aftercareTags", [])),
        )
        for p in data["professions"]
    ]


def main():
    errors = []
    reference = load("en")
    if reference is None:
        print("error: professions-en.json is missing", file=sys.stderr)
        sys.exit(1)
    expected = shape(reference)
    for code in LOCALIZATIONS:
        data = load(code)
        if data is None:
            errors.append(f"missing: professions-{code}.json")
            continue
        if data.get("localization") != code:
            errors.append(f"{code}: 'localization' says {data.get('localization')}")
        if [p["id"] for p in data["professions"]] != PROFESSIONS:
            errors.append(f"{code}: professions are not {PROFESSIONS}")
            continue
        if shape(data) != expected:
            errors.append(f"{code}: structure (keys, minutes, weeks, defaults, colors, answer counts) differs from en")
        # Keys are unique within a kind (a service and a tag may both be `makeup.bridal`): selections are kept per kind.
        seen = {"services": set(), "tags": set(), "fields": set()}
        for p in data["professions"]:
            for field in ("name", "plural"):
                if not p[field].strip():
                    errors.append(f"{code}/{p['id']}: empty {field}")
            for kind in ("services", "tags", "fields"):
                for item in p[kind]:
                    if not item["name"].strip():
                        errors.append(f"{code}/{item['key']}: empty name")
                    if len(item["name"]) > 48:
                        errors.append(f"{code}/{item['key']}: name longer than 48 characters")
                    if item["key"] in seen[kind]:
                        errors.append(f"{code}: duplicate {kind} key {item['key']}")
                    seen[kind].add(item["key"])
            if not any(s["selected"] for s in p["services"]):
                errors.append(f"{code}/{p['id']}: no preselected service")
            if not any(f["on"] for f in p["fields"]):
                errors.append(f"{code}/{p['id']}: no record field on")
            if any(t["color"] not in COLORS for t in p["tags"]):
                errors.append(f"{code}/{p['id']}: unknown tag color")
            lists = [(f["key"], f.get("tags", [])) for f in p["fields"]]
            lists += [(f"{p['id']}.reactionTags", p.get("reactionTags", [])),
                      (f"{p['id']}.aftercareTags", p.get("aftercareTags", []))]
            for name, answers in lists:
                folded = [" ".join(a.split()).lower() for a in answers]
                if any(not a.strip() or len(a) > 32 for a in answers):
                    errors.append(f"{code}/{name}: a quick answer is empty or longer than 32 characters")
                if len(set(folded)) != len(folded):
                    errors.append(f"{code}/{name}: a quick answer repeats")
            if not set(p["intake"]) <= INTAKE:
                errors.append(f"{code}/{p['id']}: unknown intake item")
            if any(s["category"].strip() == "" for s in p["services"]):
                errors.append(f"{code}/{p['id']}: empty category")
    if errors:
        print("\n".join(f"error: {e}" for e in errors), file=sys.stderr)
        sys.exit(1)
    print(f"{len(LOCALIZATIONS)} profession catalogs, {len(PROFESSIONS)} professions each: ok", file=sys.stderr)


if __name__ == "__main__":
    main()
