# s5-services: Services, ServiceEdit, AddOns, Products, Credentials, Team (S5 slice "services/catalog")

Worktree based on `build/v1` at 78a7317 (the S5 contract). Screens 6.1 Services, 6.2 ServiceEdit, 6.3 AddOns, 6.4 Products,
6.10 Credentials, 6.11 Team. Everything written in English; strings in 14 localizations (batch `s5-services.json`, 173 keys).

## What was built

- **Models** (`Models/Business/`): `Product`, `ProductCategory` (labels), `Credential`, `CredentialKind`,
  `PriceDisplay+Label`. `Models/Common/Positioned` + `PositionRules` (one owner for "next position", drag renumbering and
  "what changed"): `Service`, `AddOn`, `Product`, `Credential` conform.
- **Persistence**: `CatalogRepository` filled (add-ons, products, credentials, plus `save(_ services: [Service])` for an atomic
  reorder). `SwiftDataClientRecordRepository+Catalog`, `InMemoryClientRecordRepository+Catalog`,
  `Mapping/VaultStorable+Catalog` (nothing sealed). The only edit to a shared persistence file: four stored properties
  in `InMemoryClientRecordRepository` (`servicesByID` lost `private`; `addOnsByID`, `productsByID`, `credentialsByID`).
- **Services** (`Screens/Services/`): `ServicesView` (env wrapper) -> `ServicesContentView` (native `List`, Edit reorders,
  swipe to switch off or delete, rows with badges, empty/loading/error states), `ServicesViewModel`, `Rows/ServiceRow`,
  `Rows/ServiceBadge`, `Sheets/ServiceEditorSheet` (+ `ServiceBasicsSection`, `ServiceCategorySection`,
  `ServiceContraindicationsSection`, `ServiceRemindersSection`, `ContraindicationPickerView` pushed inside the sheet),
  `Support/` pure types: `ServiceRules`, `ServiceDraft`, `ServicePriceLine`, `ContraindicationOptions` (+ `Group`, `Option`),
  `ServiceFormIssue`, `ServiceEditorMode`, `ServicesRepository` (typealias).
- **Add-ons** (`Screens/Services/AddOns/`): list with a switch per row, reorder, delete, "What clients see" card, sheet,
  `AddOnRules`, `AddOnDraft`, `AddOnsViewModel`.
- **Products** (`Screens/Products/`): list with the Shared/Private chip (taps flip it), sheet (name, brand, kind chips, note,
  share switch), `ProductRules`, `ProductsViewModel`.
- **Credentials** (`Screens/Credentials/`): page switch (all credentials at once), list, registration number field,
  "See how it looks to clients" preview sheet, `CredentialRules`, `CredentialsViewModel`.
- **Team** (`Screens/Team/TeamView`): static, no state ("Teams are coming later" + what she will be able to decide).
- **Shared** (`Screens/Shared/`): `Choice/ChoiceChips`, `Confirmation/DeletionDialog` + `DeletionConfirm`,
  `Fields/LabeledFieldRow`, `Naming/CatalogNameCheck` + `CatalogNameRules`.
- The four placeholders (`Services`, `Products`, `Credentials`, `Team`) are deleted; `MoreTab` and `MoreView` are untouched.
  Add-ons are pushed with a closure `NavigationLink` from Services (no new `MoreRoute` case, see integration hints).
- **Bug fixes found on the way**: `PriceInput` moved to `Models/Locale/` and rewritten: an Arabic "١٢٠٫٥٠" and a Brazilian
  "12,50" with a fraction were read by `Decimal(string:locale:)` as 120 / 12 in some locales; a mark that groups thousands in
  her language ("12.50" in Brazil) is now invalid instead of 1250. `FlowLayout` answers an infinite proposal with the width
  its rows need (it used to report a non-finite size).
- **UI-test seed**: `Managers/Business/CatalogUITestSeeding.swift` (`-uiCatalog`: two more services, 4 add-ons, 3 products,
  3 credentials and a registration), called by one added line in `UITestSeeding.seedIfRequested`.

## Assumptions (ASSUMPTION candidates)

1. **Contraindications use the health-form catalog's tokens** (`pregnancy`, `allergies.latex`, `minor`), offered by
   `ContraindicationOptions` from `ContraindicationMatcher.choices(in:)` plus "Under 18". A test proves every offered token is
   decidable by the matcher in all 14 catalogs. The prototype's five fixed chips (pregnancy, isotretinoin, infection,
   sunburn, blood thinners) become the closest catalog options (isotretinoin is `recentProcedures.isotretinoin`, blood thinners
   `healthConditions.bloodThinners`). A token the catalog does not know is shown as written and kept on save.
2. **The credentials page switch is stored per credential** (`showOnBookingPage`, as docs/05 says) and the screen sets all of
   them at once; a new credential starts with the switch as it stands. With no credential the switch is only remembered in
   memory (it reads "on" again after a relaunch until there is one).
3. **The professional registration number is a `Credential` of kind `.registration`** (empty title, `registrationNumber`),
   created on the first number, updated on change, removed when the field is emptied. Not a field of `ProfessionalProfile`.
4. **Product** has `brand`, `category` (cleanser, serum, moisturizer, sun care, other) and `note` besides docs/05's `name`,
   `note`, `sharedWithClient`; **Credential** has `kind`. New products are private.
5. **Names**: a service, an add-on or a product (same brand) cannot share a name (case and accent insensitive), 60 characters.
6. **A switched-off service** stays in her list with a "Switched off" badge and is hidden from the agenda and booking page
   (S6 and S8 must read `isActive`). Deleting a service never touches appointments (they keep `serviceName`).
7. `CatalogRepository.save(_ services:)` lives in the catalog protocol, not in `AgendaRepository`, to leave the S6 agenda
   protocol alone. Move it if S6 prefers.
8. Prices in her own list: `Pricing.label` (the booking page's rule) plus "Price hidden" for `.hide`, which only she sees.

## Deviations from the prototype / design additions

- ServiceEdit omits "Pre-appointment questions" (no model field; it belongs to the booking intake, S8) and the line
  "Bello Hub learns the names you use..." (not built yet). Duration is a menu (as the setup's custom service), not six chips.
- Added: the contraindication picker (grouped, native list), "Offer this service" switch, delete with confirmation,
  inline "New category" field, "Switched off" and contraindication badges, a patch-test "How long before" menu (24/48/72 h),
  an inline empty row on Credentials (the page switch and registration stay), the Credentials preview sheet, a "+" in the
  Add-ons bar, Team lists what she will be able to decide instead of showing working controls.
- Credentials: no "Add certificate photo" (photo pipeline, S7). Institution and year are two fields, not one.
- Products: no stock, no reordering; the chip is a real button (as the prototype) with a VoiceOver hint.
- The prototype's cards became native `List` sections (insetGrouped), as the tags screen did.

## Tests

- Unit: `PositionRulesTests`, `CatalogNameRulesTests`, `PriceInputLocaleTests`, `ServiceRulesTests`, `ServicePriceLineTests`,
  `ContraindicationOptionsTests`, `ServicesViewModelTests`, `AddOnRulesTests`, `AddOnsViewModelTests`, `ProductRulesTests`,
  `ProductsViewModelTests`, `CredentialRulesTests`, `CredentialsViewModelTests`, `CatalogContrastTests`,
  `RepositoryCatalogContractTests` (both vaults, includes the contraindication and patch-test persistence exit criterion).
  Fake: `Fakes/FakeCatalogRepository`.
- UI: `ServicesUITests` (UISmoke): adds a service with a contraindication, a price and a patch test, adds an add-on, leaves
  and re-enters both screens and checks the settings. The UI-test vault is in memory, so a relaunch would start empty; the
  real-store persistence is the SwiftData contract test. `ServicesAuditUITests` (skipped by UISmoke): services, form (three
  scroll positions), picker, add-ons, add-on sheet, products, product sheet, credentials (two positions), preview, credential
  sheet, team.
- Results: see "State at the checkpoint" below.

## Findings

- Two `NavigationLink`s inside one `List` row both fire on a tap (Add-ons and Products opened together). Each is its own row.
- A `ToolbarItem(placement: .keyboard)` that appears with focus logs "Invalid frame dimension"; the number pad's Done key was
  dropped. The service form uses `.scrollDismissesKeyboard(.immediately)` so scrolling to the settings puts the pad away.
- A drag that starts low in a UI test presses a key of the keyboard: `scrollUntilVisible` drags from the upper half.
- The audit flags the name of the third product row ("may be clipped") in `en` and `ar`; screenshots show it whole. Ignored
  for the products screen only, with a comment in `ServicesAuditUITests`.

## Open questions

- Should the credentials page switch survive with no credential (needs a place to store it, for example the booking-page
  settings of the other slice)? Should the registration number move to the profile?
- Is "Under 18" worth a group of its own, or should it move to the health-form questions?
- es / es-419 differ on "Not suitable if the client has" ("No indicado" / "No recomendado"); needs_review like the rest.

## Integration hints (files likely to conflict)

- `Config/TestPlans/UISmoke.xctestplan` (both slices add an audit to `skippedTests`).
- `BelloHub/SupportFiles/UITestSeeding.swift` (one added line after the Import seeding line) and
  `Localizable.xcstrings` (regenerate with `python3 scripts/merge-strings.py`).
- `BelloHub/Managers/Persistence/InMemoryClientRecordRepository.swift` (stored properties at the top; the other slice adds its
  own, probably near `patchTestsByID`).
- `Screens/More/Placeholders/`: this slice deleted `ServicesView`, `ProductsView`, `CredentialsView`, `TeamView`; the other
  slice deletes the other three.
- If the booking slice adds routes to `MoreRoute`/`MoreTab.destination`, note `MoreTab.destination` is at 10 cases: SwiftLint's
  cyclomatic complexity limit. An 11th case needs the switch split (I avoided adding `.addOns` for that reason; Add-ons is a
  closure link, which works because it is the only such link and Products uses the typed route).
- `FlowLayout` (DesignSystem) and `PriceInput` (moved to `Models/Locale/`, was `Screens/Onboarding/Support/`).
- No `DESIGN.md` or `PROGRESS.md` edits; design additions are listed above for the coordinator.

## Strings batch

`Config/Locale/strings/s5-services.json` (173 keys: `services.*`, `addOns.*`, `products.*`, `credentials.*`, `team.*`). Reused
from earlier batches: `onb.service.*`, `more.row.*`, `tags.*` (retry, dismiss, save error, delete title, too long) by copy.

## State at the checkpoint

(filled in at the end of the run)
