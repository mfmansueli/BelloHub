# 00 · Start here

You are going to build **Bello Hub** end to end, mostly on your own. This folder is the full brief. Read this file completely, then follow the reading order in section 4.

Handoff version: **v32** (prototype: 97 screens, 103 boards). Language of everything you write (code, comments, commits, docs, PR text): **English**. The product owner reads Portuguese; the per-screen file `docs/screens/HANDOFF.md` is written in Portuguese with the exact English UI strings quoted.

---

## 1. What you are building

Bello Hub is an **iPhone app for independent beauty and aesthetic-health professionals** (esthetician, hairdresser, nail tech, lash, brow, barber, tattoo/PMU, massage). She runs her agenda and the app **remembers each client**: a living record with visit history, before/after photos, health and consent, habits, session plans, and voice-to-record. Her **clients book through a web link in any browser on any device**, with no app and no account.

Non-negotiables (full list in `01-PRODUCT.md`):

1. **No financial operations**: no payments, deposits, invoices, commissions, revenue, packages with prices. Service prices are optional information only. (The only money in the system is the professional's own Bello Hub subscription through StoreKit.)
2. **The professional uses an iPhone only.** Her clients can use **any device** (a web page). There is no Android, iPad, Mac or Windows app and no web app for the professional in v1.
3. **Client health data is private by construction**: the clinical record lives **on the iPhone and in the professional's own iCloud**. Our servers hold only the minimum operational data (see `06-PRIVACY-SECURITY.md`). The client's health form is **sealed in her browser** with the professional's public key; our server can never read it.
4. **AI runs on the device** (Apple Intelligence / on-device models). It always passes through the professional's review and never diagnoses.
5. **Ten languages, fourteen localizations from day one**: `pt-BR`, `pt-PT`, `es-MX`, `es-419`, `es`, `en`, `en-GB`, `it`, `fr`, `de`, `tr`, `id`, `hi`, `ar` (right-to-left). **Brazil and Europe are the two top priorities and open first (wave 1)**; the rest are built now and opened market by market. See `07-LOCALIZATION.md` and `16-MARKETS.md`.
6. **Calm, warm, elegant**: warm palette, Fraunces + DM Sans, one motion language, no theme or metaphor. See `08-DESIGN-SYSTEM.md` and `09-MOTION.md`.

## 2. The repository you inherit

`github.com/mfmansueli/BelloHub` already contains the architecture scaffold created by Mateus (read it before anything else):

- `CLAUDE.md`: the **architecture constitution** (MVVM + Services, folders, naming, design-system rules, tests, scripts, zero warnings, definition of done). It stays authoritative. This handoff **adds** product, privacy, data, localization and a build plan on top of it.
- `DESIGN.md`: design source of truth for the repo. You update it with every UI change (rule in `CLAUDE.md` §4). The placeholder palette in it is replaced in stage S1.
- `BelloHub.xcodeproj` (synchronized folders), `Config/*.xcconfig`, `Config/TestPlans/{Fast,Full,UISmoke}.xctestplan`, `scripts/{build,test,check-warnings,check-project-settings,lib}.sh`, `.swiftlint.yml`.
- App target folder `BelloHub/` with `DesignSystem/Tokens/{Palette,Spacing,Typography,Color+LightDark}.swift`, `Screens/{Main,Home}`, `SupportFiles/`.
- Test targets `BelloHubTests` (Swift Testing, with `ContrastRatio` helpers) and `BelloHubUITests` (XCUITest, `launchedForUITests()`).
- Minimum OS iOS 26 (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`), Swift 6, display name "Bello Hub", team `X5392U638Q`. **The scaffold still has the bundle id `com.iagoxavierdelima.BelloHub`; the decided id is `com.bellohub`** (D38), changed in S0.

### Where this handoff overrides the repo (apply in stage S0, exactly)

| Topic | Repo today | This handoff |
|---|---|---|
| Devices | `TARGETED_DEVICE_FAMILY = 1,2` | **`1`** (iPhone only). Remove iPad orientations from `App.xcconfig`. iPad-compatibility mode is not offered (`UIRequiresFullScreen` not needed). |
| `CLAUDE.md` intro and "Before writing code" paragraph | "[one-line description]", "propose… and wait for my answers" | Replace with the one-line description and the pre-answered decisions. **Do not wait for answers**: they are in `02-DECISIONS.md`. Exact text in `repo-patch/CLAUDE.md.edits.md`. |
| `CLAUDE.md` §5 languages | "[decide with me]" | The fourteen localizations above. |
| Bundle ids (`Config/App.xcconfig`, `UnitTests.xcconfig`, `UITests.xcconfig`) | `com.iagoxavierdelima.BelloHub`, `…BelloHubTests`, `…BelloHubUITests` | `com.bellohub`, `com.bellohub.BelloHubTests`, `com.bellohub.BelloHubUITests` (D38). Team stays `X5392U638Q`. |
| `DESIGN.md` identity | "Not decided yet" + blue placeholder palette | Real identity from `08-DESIGN-SYSTEM.md`. |
| Folder naming | `Managers/` holds services and protocols | Keep it. Protocol/implementation names follow `CLAUDE.md` §3 (`<Entity>Repository`, `Remote<Entity>Repository`, `Fake<Entity>Repository`). |

Everything else in the repo is kept. If you believe `CLAUDE.md` is wrong about something, **do not silently deviate**: record it in `docs/PROGRESS.md` under "Proposed changes to CLAUDE.md" and follow `CLAUDE.md` meanwhile.

## 3. How to work (autonomy contract)

You are expected to run for a long time and deliver the whole product. These rules replace "ask before you act".

**Decide, don't wait.** Every decision that matters is already made in `02-DECISIONS.md` (D-numbers). For anything not covered, pick the option that best serves the non-negotiables above, write it in `docs/PROGRESS.md` as `ASSUMPTION-n: … (reason)`, and continue.

**Hard stops** (the only reasons to stop and ask a human; write the question at the top of `PROGRESS.md`, then keep doing every task that does not depend on it):
- The environment cannot build Swift (no macOS with Xcode 26 or newer; the owner's Mac has Xcode 27). Nothing else can be validated.
- A change would store clinical data (health answers, notes, photos, audio, signatures) anywhere except the iPhone/iCloud vault, or send it to any server or third party in readable form.
- A change would add any financial operation.
- You need a secret, account or credential that does not exist yet and no safe stub is possible (see blocked-work rules).

**Blocked-work rules.** If a task needs something only a human can do (Apple Developer capabilities, Firebase project, domain, App Store Connect, real devices, legal text), do this: (1) define the protocol and a fake, (2) build everything behind the fake with tests, (3) add a precise entry to `14-HUMAN-TASKS.md` with the exact steps and the `TODO(HUMAN-Hn)` marker at the integration point, (4) continue with the next task. Never block a whole stage on a human task.

**The stage loop** (repeat for every stage in `03-BUILD-PLAN.md`):

1. Re-read `docs/PROGRESS.md` (it is your memory across context resets), then the stage text, then the screens' `HANDOFF.md` entries and **screenshots** in `design/screenshots/`.
2. Write a short plan for the stage in `PROGRESS.md` (files you will create, tests you will write).
3. Implement vertical slices: domain types and pure rules, repository/service behind a protocol and a fake, ViewModel, View, previews, tests, strings in all 14 localizations, accessibility identifiers, `DESIGN.md` update.
4. Run `scripts/build.sh`, `scripts/test.sh fast`, then `scripts/test.sh smoke`. Before closing a stage also run `scripts/check-warnings.sh` and `scripts/check-project-settings.sh`. **Zero warnings.**
5. Verify the stage's **exit criteria** (they are explicit and testable) and the `CLAUDE.md` §8 checklist. Update the traceability table in `PROGRESS.md` (screen id → status).
6. Commit (one logical change per commit, imperative subject, body explains why), tag `stage-Sn`, push. Then start the next stage immediately.

**Git.** Work on branch `build/v1` created from `main`. Push after every stage. Open a pull request into `main` at the end of each phase (A, B, C, D) with the stage reports. Never force-push `main`. Parallel work in git worktrees is allowed only as `CLAUDE.md` §7 describes; stages S8 (Firebase) and S9 (web) are naturally parallel to iOS work.

**Reports.** At the end of every stage append to `PROGRESS.md`: what was done (files), decisions and assumptions, deviations from the prototype (with reason), what was measured (contrast, test counts, timings), open questions, and the `HUMAN` tasks you created.

**Do not invent product.** The 97 prototype screens are the approved scope. A screen or feature not in `docs/screens/SCREENS.md` is out of scope; log a proposal instead. Small supporting UI that the prototype implies but does not draw (empty states, error states, an offline banner, the reminder queue described in `10-WEB-BOOKING.md` §9) is allowed: build it with existing components and list it under "Design additions" in `PROGRESS.md` so the designer can review it.

## 4. Reading order

1. `docs/01-PRODUCT.md`: product rules and the pains it solves.
2. `docs/02-DECISIONS.md`: everything decided, with numbers D1…D39, plus defaults for open items.
3. `docs/03-BUILD-PLAN.md`: stages S0…S12 with exit criteria and which screens belong to each.
4. `docs/04-ARCHITECTURE.md`: how `CLAUDE.md` applies to this product (layers, protocols, services, navigation, concurrency, offline).
5. `docs/05-DATA-MODEL.md`: every model and where it lives (iPhone/iCloud vs server vs browser).
6. `docs/06-PRIVACY-SECURITY.md`: the sealed mailbox, keys, recovery key, vault encryption, threat model, regions, laws, retention. **Read twice.**
7. `docs/07-LOCALIZATION.md` and `docs/16-MARKETS.md`: fourteen localizations, formatting, right-to-left, glossary, message templates, legal text; regions, laws, channels and the rollout by market.
8. `docs/08-DESIGN-SYSTEM.md` and `docs/09-MOTION.md`: tokens, fonts, components, animations (SwiftUI translation of the prototype).
9. `docs/10-WEB-BOOKING.md` and `docs/11-BACKEND-FIREBASE.md`: the client-facing web app and the server.
10. `docs/12-AI-AND-VOICE.md`: on-device transcription and structuring.
11. `docs/13-TESTING-QUALITY.md`: test strategy, quality gates, acceptance for v1.
12. `docs/14-HUMAN-TASKS.md`: what only a person can do, with exact steps.
13. `docs/screens/`: `SCREENS.md` (ids), `INDEX.md` (navigation), `HANDOFF.md` (behavior and texts of each screen).
14. `design/screenshots/` (what each screen looks like, 390×844 @2x) and `design/prototype/` (HTML sources; they do not run outside the design tool, so read them for structure, spacing and copy). `design/PROTOTYPE-NOTES.md` explains the prototype conventions and demo data.

## 5. Environment preflight (stage S0, first commands)

```
xcodebuild -version            # Xcode 26 or newer (the owner has Xcode 27; record beta vs release, D39)
xcrun simctl list runtimes     # an iOS 26+ runtime with an iPhone simulator
swiftlint --version            # brew install swiftlint if missing
node --version                 # 20 or newer (web + Firebase functions)
firebase --version             # npm i -g firebase-tools (emulators need Java 17+)
git --version && gh --version
```

If Xcode is missing, that is a hard stop. If only Node/Firebase tools are missing, install them and continue. Record versions in `PROGRESS.md`.

## 6. Definition of "project ready"

The project is ready for TestFlight when `13-TESTING-QUALITY.md` §8 (v1 acceptance) is fully checked, every screen in the traceability table is `done`, the privacy tests are green, and `14-HUMAN-TASKS.md` lists only items that need a person (accounts, legal review, store listing). Until then keep going stage by stage.
