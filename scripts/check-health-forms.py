#!/usr/bin/env python3
"""Usage: scripts/check-health-forms.py

Checks the health form catalogs in BelloHub/Resources/HealthForms (docs/05-DATA-MODEL.md): all fourteen
localizations exist, every one has the same questions in the same order with the same keys, kinds, professions,
defaults and choices (a translation must not change behavior), every name and prompt is filled and not absurdly long,
keys are unique, and every profession a question names exists. Only the wording may differ between languages.
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DIR = os.path.join(ROOT, "BelloHub", "Resources", "HealthForms")
LOCALIZATIONS = ["pt-BR", "pt-PT", "es-MX", "es-419", "es", "en", "en-GB", "it", "fr", "de", "tr", "id", "hi", "ar"]
PROFESSIONS = {"esthetician", "hair", "lash", "nail", "makeup", "tattoo", "barber", "massage", "other"}
KINDS = {"yesNo", "choices", "text"}
KEY = re.compile(r"^[a-z][A-Za-z0-9]*$")


def load(code):
    path = os.path.join(DIR, f"healthform-{code}.json")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def shape(data):
    """Everything that must not change between languages."""
    return [
        (
            q["key"], q["kind"], q.get("professions", []), q.get("isOnByDefault", True), q.get("allowsNone", False),
            [o["key"] for o in q.get("options", [])],
        )
        for q in data["questions"]
    ]


def main():
    errors = []
    reference = load("en")
    if reference is None:
        print("error: healthform-en.json is missing", file=sys.stderr)
        sys.exit(1)
    expected = shape(reference)
    for code in LOCALIZATIONS:
        data = load(code)
        if data is None:
            errors.append(f"missing: healthform-{code}.json")
            continue
        if data.get("localization") != code:
            errors.append(f"{code}: 'localization' says {data.get('localization')}")
        if shape(data) != expected:
            errors.append(f"{code}: structure (keys, kinds, professions, defaults, choices) differs from en")
        seen = set()
        for question in data["questions"]:
            key = question["key"]
            if not KEY.match(key):
                errors.append(f"{code}: bad question key {key}")
            if key in seen:
                errors.append(f"{code}: duplicate question key {key}")
            seen.add(key)
            if question["kind"] not in KINDS:
                errors.append(f"{code}/{key}: unknown kind {question['kind']}")
            if not set(question.get("professions", [])) <= PROFESSIONS:
                errors.append(f"{code}/{key}: unknown profession")
            for field, limit in (("name", 60), ("prompt", 140)):
                text = question.get(field, "")
                if not text.strip():
                    errors.append(f"{code}/{key}: empty {field}")
                elif len(text) > limit:
                    errors.append(f"{code}/{key}: {field} longer than {limit} characters")
            options = question.get("options", [])
            if question["kind"] == "choices" and not options:
                errors.append(f"{code}/{key}: a choices question needs options")
            if question["kind"] != "choices" and (options or question.get("allowsNone")):
                errors.append(f"{code}/{key}: only a choices question has options")
            option_keys = set()
            for option in options:
                if not KEY.match(option["key"]) or option["key"] == "none":
                    errors.append(f"{code}/{key}: bad option key {option['key']} ('none' is reserved)")
                if option["key"] in option_keys:
                    errors.append(f"{code}/{key}: duplicate option {option['key']}")
                option_keys.add(option["key"])
                if not option["name"].strip():
                    errors.append(f"{code}/{key}/{option['key']}: empty name")
                elif len(option["name"]) > 60:
                    errors.append(f"{code}/{key}/{option['key']}: name longer than 60 characters")
    if errors:
        print("\n".join(f"error: {e}" for e in errors), file=sys.stderr)
        sys.exit(1)
    print(f"{len(LOCALIZATIONS)} health form catalogs, {len(expected)} questions each: ok", file=sys.stderr)


if __name__ == "__main__":
    main()
