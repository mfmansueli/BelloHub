# Architecture and working rules for BelloHub

You are starting a new iOS app, BelloHub (minimum iOS 26): [one-line description].
Follow this document from the first commit. If code and this document disagree, the document wins.
When you touch a file that doesn't follow it, fix it in the same change.

Concrete names: target `BelloHub`, Swift module `BelloHub` (for `@testable import BelloHub`),
app type `BelloHubApp`, test targets `BelloHubTests` and `BelloHubUITests`.

Before writing code: propose the folder tree and the first feature, list the open decisions
(backend, auth, persistence), and wait for my answers. Then build.

## 1. Stack

- Pure SwiftUI. UIKit only through `UIViewRepresentable` / `UIApplicationDelegateAdaptor`.
- Swift 6, strict concurrency on. Minimum OS: iOS 26 (Liquid Glass).
- State: Observation (`@Observable`). No `ObservableObject`, `@Published` or Combine.
- Xcode project with synchronized folders: the folder on disk is the group in Xcode.
- Tests: Swift Testing for unit tests, XCUITest for UI.
- Prefer Apple frameworks. A third-party SDK (backend, analytics, ads) is allowed only if it is
  wrapped in one Service/Manager behind a protocol. Views and ViewModels never import an SDK.

## 2. Architecture: MVVM + Services, organized by feature

```
BelloHubApp ──▶ RootView (state gate: onboarding → login → setup → app)
          └─▶ MainView (TabView) ── creates the Services, injects with .environment()
                └─▶ Screens/<Feature>/  View ──owns (@State)──▶ ViewModel ──▶ Services
                                           └──(@Environment)──▶ Managers/ ◀────┘
                                                                  └─▶ backend / frameworks
```

| Layer | Folder | Responsibility | May depend on |
|---|---|---|---|
| Models | `Models/` | Domain structs/enums (`Codable`, `Identifiable`, `Hashable`, localized labels). **No IO.** | Foundation |
| Services/Managers | `Managers/` | Shared state plus all access to network, persistence and system frameworks. **The only layer that talks to the outside world.** | Models |
| ViewModels | `Screens/<Feature>/` | State and actions of one screen (or one feature's screens). Orchestrates Services. | Models, Managers |
| Views | `Screens/<Feature>/` | Layout, bindings, navigation. No direct IO. | Models, ViewModels, Managers, Design System |
| Design System | `DesignSystem/` | Tokens, styles, generic visual components. **Never** imports Screens or Managers. | Itself |
| SupportFiles | `SupportFiles/` | App entry, AppDelegate, plists, entitlements, assets, extensions. Not a junk drawer. | Apple frameworks |

Golden rule: nothing depends upward. Model doesn't know View; Design System doesn't know Screens or Managers.

### ViewModel
- Always `@MainActor @Observable final class <Feature>ViewModel`.
- The View owns it: `@State private var viewModel = HomeViewModel()`; with parameters, use
  `_viewModel = State(initialValue: …)` in the View's init.
- Dependencies come through `init` with the real implementation as default, so tests can inject fakes.
- Standard load state: `isLoading`, `isLoadingMore`, `hasMore`, `errorMessage: String?`. Re-entrancy guard on loads.
- Two entry points per action: fire-and-forget for buttons, `async` for `.refreshable`.
- Not every screen needs a VM; presentation-only screens keep local `@State`.

### Services and Managers
- `<Domain>Service` = business rules and the app's own data. `<Resource>Manager` = wrapper around an external or system resource.
- `@MainActor @Observable final class`. Anything external (network, DB, SDK) sits behind a protocol, in its own file next to the implementation.
- Created as `@State` at the root of the scope they live in (`RootView` = app session, `MainView` = signed-in user), distributed with `.environment(service)`, read with `@Environment(Type.self)`. Screens never re-create them.
- Real-time observation comes in pairs: `startListening(userId:)` / `stopListening()`, which resets state. One observation per piece of data, shared through the environment.
- Local cache lives inside the Service, keys scoped per user. Update the cache only after the remote source confirms the write.
- Singletons (`static let shared`) only when the type must be reached from outside the view tree (e.g. AppDelegate) or is pure infrastructure.
- One `SessionService` owns the current user. Nothing else reads the auth SDK.
- All UserDefaults keys live in one `enum DefaultsKey`.

### Models and pure logic
- Optionals for anything that can be missing in the source. Explicit `CodingKeys` when needed.
- Option enums: `String` raw value, `CaseIterable`, `Identifiable`, and a localized label.
- Time-dependent logic takes `now` as a parameter so it is testable.
- Business rules with no IO (filter, sort, pricing, validation) go in their own pure type (an `enum` with static funcs, or a value `struct`) in `Screens/<Feature>/Support/`.
  Each rule has exactly one owner. Never duplicate a rule between View and VM.
  When 2+ features use a type, promote it to `Models/` (data/rules) or `DesignSystem/` (visual).

### Navigation
- `RootView` is a state gate driven by `@AppStorage` flags. `MainView` is a `TabView`; each tab has its own `NavigationStack`.
- Secondary flows are sheets; celebrations and media viewers are `fullScreenCover`.
- Push/deep links: AppDelegate posts a `Notification.Name`, the UI listens.
- Use the system tab bar and system navigation bars. Don't build custom ones.

### Concurrency
- `@MainActor` on every VM and Service. Delegate methods are `nonisolated`; hop back with `Task { @MainActor in … }`.
  Wrap closure-based APIs in `async` with continuations when possible.
- `@retroactive @unchecked Sendable` conformances for third-party types live in one file, each with a comment saying why and when to remove it.
- `nonisolated(unsafe)` only with a justification comment.
- Resources whose teardown can't depend on the main actor go in a separate "handle" class.

### Backend (if any)
- The server is the source of truth for sensitive fields (premium, rewards, bans). The client only reads them, and the backend rejects client writes. Document this on the Model.
- Purchases are re-verified on the server before unlocking anything.
- Backend config and security rules are versioned in the same repo.

### Multiplatform (only if we add macOS later)
`#if os(...)` stays encapsulated in `View` extensions (`inlineNavigationTitle()`, …); screens never scatter `#if`.

## 3. Folder structure and file rules

```
BelloHub/
├── BelloHub/                # app target
│   ├── DesignSystem/ { Tokens/, Styles/, Components/, Backgrounds/, Fonts/ }
│   ├── Managers/            # Services + protocols
│   ├── Models/
│   ├── Screens/
│   │   ├── Main/            # RootView, MainView (+ Support/ for root-state screens)
│   │   ├── Shared/<Concept>/    # screens used by several features
│   │   └── <Feature>/ { <Feature>View, <Feature>ViewModel, Cards/, Rows/, Sheets/, Support/, <SubFeature>/ }
│   └── SupportFiles/        # BelloHubApp, AppDelegate, plists, entitlements, xcstrings, assets, ViewExtensions
├── BelloHubTests/           # Swift Testing; Fakes/ folder; mirrors the app's subfolders
├── BelloHubUITests/         # XCUITest; one file per user flow
├── Config/                  # *.xcconfig
├── scripts/
└── DESIGN.md                # source of truth for design; updated with the UI
```
Create a subfolder only when there is a file for it. A small feature can be just a View.

- **One top-level type per file** (struct/class/enum/actor/protocol). Nested types are fine when they belong to the parent type.
  A protocol and its implementation are two files. Several tightly related files go in a subfolder named after the concept, not loose in a generic folder. Group by feature/concept, never by file kind.
- Naming: `<Feature>View`, `<Feature>ViewModel`, `<Domain>Service`, `<Resource>Manager`, `<Entity>Repository` (protocol),
  `Remote<Entity>Repository` / `Fake<Entity>Repository` (fake lives only in the tests target), `<Thing>Row` / `<Thing>Sheet`,
  `<Type>+<Topic>.swift`, `<Type>Tests.swift`, `<Flow>UITests.swift`.
- Accessibility identifiers: `"<screen>.<element>[.<id>]"` in camelCase.
- File anatomy: header with name and target → `@State` + VM → `@Environment` → constants → computed helpers → `body` → private section subviews → private functions → `#Preview` with every
  `.environment(...)` it needs.
  `// MARK: -` in VMs and Services.
- Comments explain *why* (motivation, failed attempts, trade-offs), not *what*. `///` doc comments on Service APIs.
- **When to split:** extract sections as `private var header: some View` first. If a section has its own state, is reused, or the View passes ~400 lines, move it to its own file.
  Logic in a View/VM goes to a `Support/` type and gets tested.

## 4. Design System

- Tokens: a `Palette` enum with semantic names (`bg`, `surface`, `ink`, `ink2`, `accent`, …), each light/dark via `Color(light:dark:)`; a font token with `relativeTo:` for Dynamic Type; spacing/radius tokens.
  Area-specific colors go in their own namespace/file, so core tokens stay small.
- Styles: one `ButtonStyle` with an `enum Variant` and static helpers, so screens never build a style by hand.
- Components: generic, with no business rules, exposed as `View` extensions.
- Rules: no hex color, font or radius literal in `Screens/` (if missing, create the token). One primary action style per screen.
- Prefer native components (sheets, menus, pickers, toolbars, segmented controls). Build a custom one only when the native one can't do the job, with a comment saying why.
- `DESIGN.md` at the root is the design source of truth (identity, tokens, components, screen inventory, navigation tree, empty/loading/error states, motion, accessibility). Update it in the
  same change as the UI.

## 5. Strings, accessibility, contrast, debug flags

- Every visible string is localized from day one (String Catalog + `String(localized:)`), including enum labels. Languages: [decide with me].
- Icon-only buttons have `accessibilityLabel`. Cards combine children into one element. 44×44 pt minimum touch target. Continuous animations respect Reduce Motion.
- **Contrast (WCAG 2.2 AA):** text ≥ 4.5:1 against what is actually behind it (≥ 3:1 for large text); UI parts, informative icons and field borders ≥ 3:1.
  Measure on the worst point of the real surface (glass, gradients, video), not the average token.
  Use only the `Palette` text tokens; never invent `.opacity(x)` for text. Every text/background pair has a test that measures it (with and without Increase Contrast).
- Debug/admin tools and test-data generation sit behind `#if DEBUG` or an admin permission. Local overrides ("pretend premium") never ship.
- UI-test hooks are launch arguments handled in `#if DEBUG` (for example `-uiTesting`).

## 6. Tests (written with the feature, not after)

- Unit (Swift Testing): `@Suite("<Type>")` + `struct <Type>Tests`; test names are descriptive; build data with `makeX()` factories; VMs get fakes in `init`, never the real thing.
  Fixed, injected time (`now`). Isolate UserDefaults with unique ids per test and clean up with `defer`. Prioritize pure logic: it is the cheapest and most valuable to test.
- Async: wait on a condition (a `Wait.until { … }` helper with a timeout), never a fixed delay or a `sleep`. `sleep` only to prove something does *not* happen.
- UI (XCUITest): controlled initial state via launch arguments; find elements by `accessibilityIdentifier`, not by text; `XCTSkip` when the environment precondition is missing;
  helpers under `// MARK: - Helpers`; launch through one helper that disables animations; wait on conditions (`waitForExistence`), not `sleep`.
- Test plans: Fast (unit only), UISmoke (one UI test per flow), Full (everything, the default).

## 7. Build and process

- Build settings live in `Config/*.xcconfig` (Project, App, UnitTests, UITests), never in `project.pbxproj`; a script checks the project file.
- Build and test through `scripts/` wrappers (`build.sh`, `test.sh [fast|smoke|full]`):
  one DerivedData per checkout inside the repo (`build/`), one `xcodebuild` at a time, only errors/warnings/failures printed, full log saved to `build/logs/`.
- **Zero warnings** (compiler, SwiftLint, Xcode tools). Fix any warning you see, even ones you didn't cause.
  A `check-warnings.sh` does clean builds for simulator, device and Release before a feature is declared done.
- SwiftLint runs in every build with a committed `.swiftlint.yml`. Fix the code instead of disabling the rule.
- Release must also compile: debug/preview data sits behind `#if DEBUG`.
- Parallel sessions each use their own git worktree. Never create simulators or DerivedData folders outside the repo; clean up temp files when a session ends.

## 8. Definition of done (checklist for every feature)

- [ ] `Screens/<Feature>/` with View (+ ViewModel if there is state or IO)
- [ ] One type per file; subfolders only when needed
- [ ] Shared Services read via `@Environment`, not re-created
- [ ] External access behind a protocol; no SDK import in a View or ViewModel
- [ ] Business rules extracted into a pure type in `Support/` or `Models/`
- [ ] Colors, fonts and components from `DesignSystem/`; no loose values
- [ ] Empty, loading and error states defined
- [ ] Localized text; accessibility labels and identifiers
- [ ] Light and dark checked; Reduce Motion respected; contrast measured
- [ ] Sensitive fields set only by the server (if there is a backend)
- [ ] Unit and UI tests in the same delivery
- [ ] `DESIGN.md` updated if the UI changed
- [ ] Zero warnings; Fast tests pass

## 9. Mistakes to avoid from the start (learned the hard way on a previous app)

1. No SDK outside Services. Otherwise changing backend means touching dozens of files.
2. Centralized session. Don't read the user id from the auth SDK in Views.
3. UserDefaults keys in one `DefaultsKey` enum, not scattered strings.
4. Split big Views early (a 950-line View is where it went wrong).
5. `SupportFiles/` is not a drawer: reusable screens go in `Screens/Shared/<Concept>/`.
6. A business rule has one owner (the sort that lived in both View and VM).
