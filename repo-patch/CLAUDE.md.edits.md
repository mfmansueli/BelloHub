# Repo edits to apply in stage S0

Apply these exactly, in one commit titled `Adopt Bello Hub handoff`. They connect the repo's architecture documents to this handoff. Nothing else in `CLAUDE.md` changes.

## `CLAUDE.md`

1. Replace the first sentence

   `You are starting a new iOS app, BelloHub (minimum iOS 26): [one-line description].`

   with

   `You are building BelloHub (minimum iOS 26, iPhone only): an app for independent beauty and aesthetic-health professionals that runs their agenda and remembers each client in a private, living record, with a web booking link for the clients. Product, privacy, data, localization, motion and the build plan live in docs/ (index: docs/README.md).`

2. Replace the paragraph that starts `Before writing code: propose the folder tree…` with

   `Before writing code, read docs/00-START-HERE.md. The open decisions (backend, auth, persistence, languages) are already answered in docs/02-DECISIONS.md; do not wait for answers, follow docs/03-BUILD-PLAN.md. Read docs/06-PRIVACY-SECURITY.md before touching persistence, networking, notifications, logging or AI: clinical data never leaves the iPhone vault or the sealed mailbox.`

3. In §1 Stack, after the line `Swift 6, strict concurrency on. Minimum OS: iOS 26 (Liquid Glass).` add

   `- iPhone only (TARGETED_DEVICE_FAMILY = 1). Clients use a web page on any device (web/).`

4. In §5, replace `Languages: [decide with me].` with

   `Languages: ten languages in fourteen localizations: pt-BR, pt-PT, es-MX, es-419, es (Spain), en (US), en-GB, it, fr, de, tr, id, hi, ar (right-to-left). Every string exists in all of them in the same change (docs/07-LOCALIZATION.md); es-419 and en-GB are derived by scripts/derive-locales.py. Brazil and Europe are the first markets (docs/16-MARKETS.md).`

5. In §3 folder structure, add the sibling folders `firebase/`, `web/`, `docs/`, `design/` next to `Config/` and `scripts/`, with one line each: `firebase/ # rules, functions, emulator tests`, `web/ # client booking web app`, `docs/ # handoff and progress`, `design/ # prototype sources and screenshots (read-only)`.

## `Config/Project.xcconfig`
`TARGETED_DEVICE_FAMILY = 1`

## Bundle ids (decision D38)
- `Config/App.xcconfig`: `PRODUCT_BUNDLE_IDENTIFIER = com.bellohub`
- `Config/UnitTests.xcconfig`: `PRODUCT_BUNDLE_IDENTIFIER = com.bellohub.BelloHubTests`
- `Config/UITests.xcconfig`: `PRODUCT_BUNDLE_IDENTIFIER = com.bellohub.BelloHubUITests`
- `DEVELOPMENT_TEAM = X5392U638Q` stays.
- Search the whole repo (`grep -rn iagoxavierdelima .`) and fix every remaining hit (scripts, test plans, README, DESIGN.md).
- Keep `IPHONEOS_DEPLOYMENT_TARGET = 26.0` even though the owner's Xcode is 27 (D39).

## `Config/App.xcconfig`
Delete the line `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = …`. Add `CODE_SIGN_ENTITLEMENTS = BelloHub/SupportFiles/BelloHub.entitlements` only after the entitlements file exists (stage S2; see H1).

## `DESIGN.md`
Replace the *Identity* and *Tokens → Color* sections with the identity and tokens from `docs/08-DESIGN-SYSTEM.md` in stage S1. Keep the other sections and keep updating them with the UI.

## `README.md`
Append a short "Handoff" section pointing to `docs/README.md` and to the commands for the emulators, the web app and the e2e script as they come to exist.

## `.gitignore` (append)
```
node_modules/
.firebase/
firebase-debug.log
web/dist/
*.local.xcconfig
.env.local
```

## Do not edit
`design/` (reference material from the designer). Record anything you learn about it in `docs/PROGRESS.md`.
