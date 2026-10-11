#!/usr/bin/env python3
"""Localization source scan (routine-a item 1), run by scripts/test.sh fast.

Reads the app's Swift sources and fails on the patterns that left parts of the app in the wrong language:
- a catalog key resolved with String(localized:), which always answers in the launch language (it ignores the
  interface language, `\\.locale` and its own `locale:` argument): use String(interface:) or .resolved(in: locale);
- String(localized: ..., locale: ...) relying on the locale argument to choose the language;
- the device locale (Locale.current, autoupdatingCurrent, preferredLanguages) outside the files that may read it;
- a visible English sentence typed into a view in Screens/ (Text, Button, Label, navigationTitle, ...).
Preview blocks (#Preview and after) are not scanned: preview data may be English on purpose.
`--self-test` proves each rule fires on a sample.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "BelloHub")

# Files that may read the device locale, with the reason.
DEVICE_LOCALE_ALLOWED = {
    "Managers/Locale/InterfaceLanguageService.swift": "the owner of the interface language reads the device",
    "Models/Locale/InterfaceLocale.swift": "the starting value until InterfaceLanguageService sets it at launch",
    "DesignSystem/Tokens/Typography.swift": "a default argument; LocaleTypography passes the environment's locale",
    "Screens/Treatment/TreatmentFlowViewModel.swift": "a starting value; the host sets the environment's locale",
    "Screens/Main/RootView.swift": "the region of the first sign-in screen, not text",
    "Screens/Onboarding/SetupView.swift": "the device region for the business region, not text",
    "Screens/Clients/Import/ImportClientsView.swift": "the device region for phone numbers, not text",
}

# Agent B of the routine-simplification task owns these screens on its own branch (routine-b), so agent A left their
# String(localized:) calls untouched to avoid conflicts. After the merge, convert them (String(interface:) outside
# views, .resolved(in: locale) inside) and empty this list.
PENDING_ROUTINE_B = {
    "Screens/Availability/AvailabilityViewModel.swift",
    "Screens/Availability/Sheets/BreakSheet.swift",
    "Screens/BookingSettings/BookingSettingsViewModel.swift",
    "Screens/BookingSettings/Support/BookingSetupEditor.swift",
    "Screens/Services/AddOns/AddOnsViewModel.swift",
    "Screens/Services/ServicesViewModel.swift",
}

RULES = [
    ("literal-key", re.compile(r'String\(\s*localized:\s*"'),
     "a catalog key resolved with String(localized:) stays in the launch language; "
     "use String(interface:) or .resolved(in: locale)"),
    ("locale-argument", re.compile(r'String\(localized:[^()\n]*(\([^()\n]*\)[^()\n]*)*,\s*locale:'),
     "String(localized:)'s locale: argument only formats; set the resource's locale"),
    ("device-locale", re.compile(r'(?<![A-Za-z])Locale\.(current|autoupdatingCurrent|preferredLanguages)\b'),
     "the device locale used outside the allowed files; use the environment's locale or InterfaceLocale"),
    ("sentence-literal",
     re.compile(r'\b(Text|Button|Label|navigationTitle|accessibilityLabel|accessibilityHint|Toggle)\(\s*'
                r'"([^"\\]*\s[^"\\]*)"'),
     "visible English typed into a view; use a catalog key, or Text(verbatim:) for her own words"),
]


def scanned(text):
    index = text.find("#Preview")
    return text if index < 0 else text[:index]


def problems(relative, text):
    code = scanned(text)
    found = []
    for name, pattern, why in RULES:
        if name == "device-locale" and relative in DEVICE_LOCALE_ALLOWED:
            continue
        if name == "sentence-literal" and not relative.startswith("Screens/"):
            continue
        if name == "literal-key" and relative in PENDING_ROUTINE_B:
            continue
        for match in pattern.finditer(code):
            line = code.count("\n", 0, match.start()) + 1
            found.append(f"BelloHub/{relative}:{line}: {match.group(0).strip()} -> {why}")
    return found


def self_test():
    samples = {
        "literal-key": 'let a = String(localized: "home.title")',
        "locale-argument": 'let a = String(localized: key, locale: locale)',
        "device-locale": "let region = Locale.current.region",
        "sentence-literal": 'Text("Good morning")',
    }
    for name, sample in samples.items():
        if not problems("Screens/Sample.swift", sample):
            print(f"self-test: rule {name} did not fire", file=sys.stderr)
            return 1
    if problems("Screens/Sample.swift", '#Preview { Text("Preview only") }'):
        print("self-test: a preview was scanned", file=sys.stderr)
        return 1
    print("localization source scan self-test: ok")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    errors = []
    count = 0
    for folder, _, names in os.walk(APP):
        for name in sorted(names):
            if not name.endswith(".swift"):
                continue
            path = os.path.join(folder, name)
            relative = os.path.relpath(path, APP)
            with open(path, encoding="utf-8") as handle:
                errors += problems(relative, handle.read())
            count += 1
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        print(f"Localization source scan failed: {len(errors)} problem(s)", file=sys.stderr)
        return 1
    print(f"Localization source scan: {count} Swift files, no problem")
    return 0


if __name__ == "__main__":
    sys.exit(main())
