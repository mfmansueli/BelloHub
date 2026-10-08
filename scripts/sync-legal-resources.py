#!/usr/bin/env python3
"""Usage: scripts/sync-legal-resources.py [--check]

The legal documents the app shows (the three consent texts) are drafts under legal/<document>/<localization>/
<version>.md. The app bundle has no folders, so each file is bundled flat as BelloHub/Resources/Legal/
<document>-<localization>-<version>.md (for example consent-health-pt-BR-2026-10.md), byte for byte. Every version
stays: a consent stores the version it was signed on and must be shown again exactly (ASSUMPTION-24).

Without arguments it copies the files and removes bundled files that no longer exist under legal/.
With --check it changes nothing and fails (exit 1) when a bundled copy is missing, differs from legal/ or has no
source: that is what scripts/check-legal-resources.sh runs. The legal drafts themselves are never edited here.
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LEGAL = os.path.join(ROOT, "legal")
BUNDLED = os.path.join(ROOT, "BelloHub", "Resources", "Legal")
DOCUMENTS = ["consent-health", "consent-photo", "consent-guardian"]


def sources():
    """Maps the bundled file name to the path of its source under legal/."""
    found = {}
    for document in DOCUMENTS:
        folder = os.path.join(LEGAL, document)
        if not os.path.isdir(folder):
            continue
        for localization in sorted(os.listdir(folder)):
            localization_folder = os.path.join(folder, localization)
            if not os.path.isdir(localization_folder):
                continue
            for name in sorted(os.listdir(localization_folder)):
                if name.endswith(".md"):
                    found[f"{document}-{localization}-{name}"] = os.path.join(localization_folder, name)
    return found


def read(path):
    with open(path, "rb") as handle:
        return handle.read()


def bundled_names():
    if not os.path.isdir(BUNDLED):
        return set()
    return {name for name in os.listdir(BUNDLED) if name.endswith(".md")}


def main():
    check = "--check" in sys.argv[1:]
    expected = sources()
    problems = []
    if not expected:
        problems.append("no consent documents found under legal/")

    for name, source in sorted(expected.items()):
        target = os.path.join(BUNDLED, name)
        if not os.path.exists(target):
            problems.append(f"missing: Resources/Legal/{name}")
            if not check:
                os.makedirs(BUNDLED, exist_ok=True)
                with open(target, "wb") as handle:
                    handle.write(read(source))
        elif read(target) != read(source):
            problems.append(f"differs from legal/: Resources/Legal/{name}")
            if not check:
                with open(target, "wb") as handle:
                    handle.write(read(source))

    for name in sorted(bundled_names() - set(expected)):
        problems.append(f"no source under legal/: Resources/Legal/{name}")
        if not check:
            os.remove(os.path.join(BUNDLED, name))

    if check:
        if problems:
            print("\n".join(f"error: {problem}" for problem in problems), file=sys.stderr)
            print("error: run scripts/sync-legal-resources.sh and commit the result", file=sys.stderr)
            sys.exit(1)
        print(f"{len(expected)} bundled legal texts match legal/: ok", file=sys.stderr)
        return
    print(f"{len(expected)} legal texts in Resources/Legal ({len(problems)} changed)", file=sys.stderr)


if __name__ == "__main__":
    main()
