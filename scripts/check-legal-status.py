#!/usr/bin/env python3
"""Usage: scripts/check-legal-status.py [--write]

Checks the legal drafts under legal/ and prints a status table. Fails (exit 1) when a document or a localization is
missing, a header field is absent, a placeholder is unknown, or a text makes a claim `docs/06-PRIVACY-SECURITY.md`
section 12 forbids (absolute security, legal compliance). With --write it also rewrites the table in legal/STATUS.md.
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LEGAL = os.path.join(ROOT, "legal")
DOCUMENTS = ["terms-dpa", "privacy-policy", "client-notice", "consent-health", "consent-photo", "consent-guardian",
             "data-requests"]
LOCALIZATIONS = ["pt-BR", "pt-PT", "es-MX", "es-419", "es", "en", "en-GB", "it", "fr", "de", "tr", "id", "hi", "ar"]
REQUIRED = ["document", "localization", "region", "version", "status", "framework"]
PLACEHOLDERS = {"OPERATOR_NAME", "OPERATOR_EMAIL", "OPERATOR_ADDRESS", "WEB_BASE_URL", "EFFECTIVE_DATE",
                "PROFESSIONAL_NAME"}
# Claims the copy rules forbid (docs/06-PRIVACY-SECURITY.md section 12), in English; local equivalents are caught by review.
FORBIDDEN = ["unhackable", "impossible to intercept", "100% secure", "military-grade", "fully compliant",
             "gdpr compliant", "gdpr-compliant", "lgpd compliant", "guaranteed secure"]
BEGIN, END = "<!-- table:start -->", "<!-- table:end -->"


# The European set (docs/16-MARKETS.md section 2): a common GDPR core plus a national annex. From version 2026-10-2
# the terms and the privacy policy of these localizations say so in their header and carry both parts.
EUROPEAN = {"pt-PT": "PT", "es": "ES", "it": "IT", "fr": "FR", "de": "DE", "en-GB": "UK"}
CORE_DOCUMENTS = ["terms-dpa", "privacy-policy"]


def version_key(name):
    """2026-10 < 2026-10-2 < 2026-10-10: compared as numbers, the way the app and the page pick the newest."""
    return [int(part) for part in re.findall(r"\d+", name)]


def parse(path):
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    match = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
    if not match:
        return None, text
    header = {}
    for line in match.group(1).splitlines():
        key, _, value = line.partition(":")
        header[key.strip()] = value.strip()
    return header, match.group(2)


def main():
    errors, rows = [], []
    for document in DOCUMENTS:
        for localization in LOCALIZATIONS:
            folder = os.path.join(LEGAL, document, localization)
            versions = sorted((f for f in os.listdir(folder) if f.endswith(".md")), key=version_key) \
                if os.path.isdir(folder) else []
            if not versions:
                errors.append(f"missing: legal/{document}/{localization}/")
                continue
            path = os.path.join(folder, versions[-1])
            header, body = parse(path)
            rel = os.path.relpath(path, ROOT)
            if header is None:
                errors.append(f"{rel}: no header")
                continue
            for field in REQUIRED:
                if not header.get(field):
                    errors.append(f"{rel}: header field '{field}' is missing")
            if header.get("document") != document or header.get("localization") != localization:
                errors.append(f"{rel}: header does not match its folder")
            if header.get("version") != versions[-1][:-3]:
                errors.append(f"{rel}: header version differs from the file name")
            for name in set(re.findall(r"\{\{([A-Z_]+)\}\}", body)) - PLACEHOLDERS:
                errors.append(f"{rel}: unknown placeholder {{{{{name}}}}}")
            lowered = body.lower()
            for phrase in FORBIDDEN:
                if phrase in lowered:
                    errors.append(f"{rel}: forbidden claim '{phrase}'")
            if document in CORE_DOCUMENTS and localization in EUROPEAN and version_key(versions[-1]) >= [2026, 10, 2]:
                annex = EUROPEAN[localization]
                if not header.get("structure", "").startswith("gdpr-core") or annex not in header.get("structure", ""):
                    errors.append(f"{rel}: header 'structure' must name the GDPR core and the {annex} annex")
                if body.count("\n# ") < 2:
                    errors.append(f"{rel}: needs Part A (common core) and Part B (national annex) headings")
            if len(body.split()) < 40:
                errors.append(f"{rel}: suspiciously short")
            rows.append((document, localization, header.get("region", ""), header.get("version", ""),
                         header.get("status", ""), header.get("framework", "")))
    table = "| Document | Localization | Region set | Version | Status | Framework |\n|---|---|---|---|---|---|\n"
    table += "\n".join("| " + " | ".join(row) + " |" for row in rows)
    print(table)
    if "--write" in sys.argv:
        status_path = os.path.join(LEGAL, "STATUS.md")
        with open(status_path, encoding="utf-8") as handle:
            text = handle.read()
        block = f"{BEGIN}\n{table}\n{END}"
        if BEGIN in text:
            text = re.sub(re.escape(BEGIN) + ".*?" + re.escape(END), lambda _: block, text, flags=re.S)
        else:
            text = text.rstrip() + "\n\n" + block + "\n"
        with open(status_path, "w", encoding="utf-8") as handle:
            handle.write(text)
    if errors:
        print("\n".join(f"error: {e}" for e in errors), file=sys.stderr)
        sys.exit(1)
    print(f"\n{len(rows)} documents, {len(DOCUMENTS)} kinds x {len(LOCALIZATIONS)} localizations: all present", file=sys.stderr)


if __name__ == "__main__":
    main()
