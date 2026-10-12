#!/usr/bin/env python3
"""Usage: scripts/check-strings.py [--final]

Fails (exit 1) on: a key missing from any of the fourteen localizations, an empty value, a missing plural
category (all six for ar), a placeholder mismatch, a hard-coded text literal in Screens/, a key used in code
that is absent from the catalog, or a derived localization (es-419, en-GB) that is out of date.
It also fails on the style rules of docs/07-LOCALIZATION.md that a script can see (S11): one address per
audience (the app speaks to the professional as du / tu / kamu / siz; the messages and rules a client reads keep
the polite form), regional vocabulary from docs/strings/glossary.csv (pt-PT never says "você" or "agendamento", es
never "celular"...), no gender slashes or stars, Arabic punctuation, American spelling in en and British in en-GB.
Always prints a coverage table (languages x translated x needs review).
With --final (stage S11 and later) it also fails on any `needs_review` string whose language is not in
the allowed list in docs/PROGRESS.md section "Strings awaiting reviewers" (every non-English localization stays
listed there until a human promotes it; D41).
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

# Strings a client reads (messages she sends, rules on the booking page, the QR card and share texts). They keep
# the polite address (de Sie, id Anda, tr siz) while the app speaks to the professional informally.
CLIENT_FACING = re.compile(r"^(policy\.rule\.|quickReplies\.default\.\w+\.text(\.v1)?$|appointment\.message\.|"
                           r"clientMessage\.(birthday|general)$|shareLink\.(card\.|instagram\.text$|whatsapp\.text$|message$)|"
                           r"waitlist\.offerMessage$|clientText\.)")
# Strings that speak to the professional and quote what a client reads, so both addresses appear in them.
MIXED_ADDRESS = {"clientEdit.stop.hint"}
# (localization, pattern, why). Applied to every value of the localization; `app` rules skip client-facing keys,
# `client` rules apply only to them.
STYLE_RULES = [
    ("pt-PT", "all", r"\b(você|vocês|celular|agendamentos?|tela|usuári[oa]s?|contatos?|equipe|aplicativo|câmera|"
                     r"registros?|salvar|salvo|excluir|excluíd[oa]s?|Oi)\b", "pt-BR word in pt-PT (glossary)"),
    ("pt-PT", "all", r"ligação de marcação", "pt-PT says link de marcação (glossary)"),
    ("pt-BR", "all", r"\b(telemóvel|marcaç(ão|ões)|registos?|ficheiros?|ecrã|utilizador(es|a|as)?|contactos?|"
                     r"equipa|desmarc\w*)\b", "pt-PT word in pt-BR (glossary)"),
    ("es", "all", r"\b(celular(es)?|computadora|costo)\b", "Latin American word in es (Spain)"),
    ("es-MX", "all", r"\b(móvil(es)?|ordenador|coste|vosotr\w+|vuestr\w+)\b", "Spain word in es-MX"),
    ("de", "app", r"\b\w+en Sie\b|(?<=[a-zäöüß,] )(Ihnen|Ihr|Ihre|Ihren|Ihrem|Ihrer|Ihres)\b",
     "the app says du to the professional"),
    ("de", "client", r"\b(du|dich|dir|dein\w*)\b", "client texts say Sie"),
    ("de", "all", r"\w[*:_/]in(nen)?\b|\bKund(e|en|in|innen)\b", "gender-neutral German: Kundschaft or Person"),
    ("fr", "all", r"\b(tu|ton|ta|tes|toi)\b", "French says vous everywhere"),
    ("fr", "all", r"\bvous seule?\b", "neutral French: visible par vous uniquement"),
    ("tr", "app", r"\b(sen|senin|sana|seni|sende)\b|\b(dene|kontrol et|aç|seç|yaz|dokun|gir)[.!]",
     "the app says siz to the professional"),
    ("id", "app", r"\bAnda\b", "the app says kamu to the professional"),
    ("id", "client", r"\bkamu\b", "client texts say Anda"),
    ("hi", "all", r"तुम|तेरा|तेरी", "Hindi uses आप"),
    ("ar", "all", r"[?;]|(?<=[\u0600-\u06FF]),", "Arabic punctuation: ؟ ؛ ،"),
    ("en", "all", r"\b(colour\w*|organis\w*|authoris\w*|recognis\w*|customis\w*|personalis\w*|prioritis\w*|"
                  r"summaris\w*|synchronis\w*|analys(e|ed|es|ing)|favourite\w*|centre\w*|tick|ticked|whilst|programme)\b",
     "en is American English"),
    ("en-GB", "all", r"\b(color\w*|\w+iz(e|ed|es|ing)\b|favorite|center|waitlist|vacation|toward)\b",
     "en-GB is British English"),
    ("*", "all", r"^\s|\s$|  |\.\.\.", "no stray spaces; use … for an ellipsis"),
    ("*", "all", r"\w/(a|as|o|os|e|es|in|innen)\b|\((a|as|o|os|e|es|in|innen)\)", "no gender slashes or brackets"),
]


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


def check_style(catalog, errors):
    for key, entry in sorted(catalog.get("strings", {}).items()):
        client = bool(CLIENT_FACING.match(key))
        for language, scope, pattern, why in STYLE_RULES:
            if scope == "app" and client or scope == "client" and not client:
                continue
            if scope != "all" and key in MIXED_ADDRESS:
                continue
            languages = lib.LOCALIZATIONS if language == "*" else [language]
            for code in languages:
                for text in lib.entry_values(entry.get("localizations", {}).get(code)).values():
                    match = re.search(pattern, text)
                    if match:
                        errors.append(f"style: {key} [{code}] \"{match.group(0)}\": {why}")


def awaiting_reviewers():
    """Localizations listed in docs/PROGRESS.md under "Strings awaiting reviewers" (a line of backticked ids)."""
    path = os.path.join(lib.ROOT, "docs", "PROGRESS.md")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    match = re.search(r"## Strings awaiting reviewers\n(.*?)(\n## |\Z)", text, re.S)
    return set(re.findall(r"`([a-zA-Z0-9-]+)`", match.group(1))) if match else set()


def check_final(catalog, errors):
    allowed = awaiting_reviewers()
    pending = {}
    for key, entry in catalog.get("strings", {}).items():
        for language in lib.LOCALIZATIONS:
            if lib.entry_state(entry.get("localizations", {}).get(language)) == "needs_review":
                pending.setdefault(language, []).append(key)
    for language, keys in sorted(pending.items()):
        if language not in allowed:
            errors.append(f"final: {len(keys)} strings in {language} need review but {language} is not listed under "
                          f"'Strings awaiting reviewers' in docs/PROGRESS.md")
    print("awaiting reviewers: " + ", ".join(f"{language} {len(keys)}" for language, keys in sorted(pending.items())))


def check_web_style(errors):
    """The booking pages (web/src/i18n) follow the same rules; every web string is read by a client, so the client
    address applies (de Sie, id Anda, tr siz, pt-PT without você, fr vous)."""
    import json
    folder = os.path.join(lib.ROOT, "web", "src", "i18n")
    client_address = [("de", r"\b(du|dich|dir|dein\w*)\b"), ("id", r"\bkamu\b"), ("tr", r"\b(sen|senin|sana|seni)\b")]
    rules = [(language, pattern, why) for language, scope, pattern, why in STYLE_RULES if scope != "app"]
    rules += [(language, pattern, "client texts use the polite address") for language, pattern in client_address]
    for code in lib.LOCALIZATIONS:
        path = os.path.join(folder, code + ".json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as handle:
            values = json.load(handle)
        texts = []
        for key, value in values.items():
            texts += [(key, text) for text in (value.values() if isinstance(value, dict) else [value])
                      if isinstance(text, str)]
        for language, pattern, why in rules:
            if language not in ("*", code):
                continue
            for key, text in texts:
                match = re.search(pattern, text)
                if match:
                    errors.append(f"web style: {key} [{code}] \"{match.group(0)}\": {why}")


def check_docs_strings(errors):
    """docs/strings: the glossary has a term in every localization, and the message templates have every kind in
    every localization with the same placeholders as English (docs/07-LOCALIZATION.md sections 4 and 6)."""
    import csv
    import json
    folder = os.path.join(lib.ROOT, "docs", "strings")
    with open(os.path.join(folder, "glossary.csv"), encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            for language in lib.LOCALIZATIONS:
                if not (row.get(language) or "").strip():
                    errors.append(f"glossary: '{row['key']}' has no {language} term")
    with open(os.path.join(folder, "message-templates.json"), encoding="utf-8") as handle:
        locales = json.load(handle)["locales"]
    english = locales.get(lib.SOURCE_LANGUAGE, {}).get("messages", {})
    for language in lib.LOCALIZATIONS:
        messages = locales.get(language, {}).get("messages")
        if messages is None:
            errors.append(f"message-templates: {language} is missing")
            continue
        for kind, text in english.items():
            if kind not in messages:
                errors.append(f"message-templates: {language} has no '{kind}'")
            elif sorted(set(re.findall(r"\{\w+\}", messages[kind]))) != sorted(set(re.findall(r"\{\w+\}", text))):
                errors.append(f"message-templates: {language} '{kind}' placeholders differ from English")


def check_navigation_titles(errors):
    """Every `.navigationTitle` key in Screens/ is measured by BelloHubTests NavigationTitleFitTests, in the list of its
    display mode (inline when an `.inline` display mode follows within three lines, large otherwise)."""
    test = os.path.join(lib.ROOT, "BelloHubTests", "Models", "Locale", "NavigationTitleFitTests.swift")
    with open(test, encoding="utf-8") as handle:
        text = handle.read()
    listed = {}
    for name, mode in (("largeTitleKeys", "large"), ("inlineTitleKeys", "inline")):
        block = re.search(name + r" = \[(.*?)\]", text, re.S)
        for key in re.findall(r'"([^"]+)"', block.group(1) if block else ""):
            listed[key] = mode
    for path in swift_files("BelloHub/Screens"):
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().split("\n")
        for index, line in enumerate(lines):
            if ".navigationTitle(" not in line:
                continue
            keys = re.findall(r'"([a-z][A-Za-z]*\.[A-Za-z.]+)"', " ".join(lines[index:index + 2]))
            mode = "inline" if "(.inline)" in "\n".join(lines[index:index + 4]) else "large"
            for key in keys:
                if listed.get(key) != mode:
                    errors.append(f"{os.path.relpath(path, lib.ROOT)}: title {key} is {mode}; list it under "
                                  f"{'inlineTitleKeys' if mode == 'inline' else 'largeTitleKeys'} in "
                                  "NavigationTitleFitTests")


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
    check_style(catalog, errors)
    check_docs_strings(errors)
    check_web_style(errors)
    check_navigation_titles(errors)
    if os.path.exists(lib.INFOPLIST_CATALOG):
        check_style(lib.load_catalog(lib.INFOPLIST_CATALOG), errors)
    if "--final" in sys.argv:
        check_final(catalog, errors)
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
