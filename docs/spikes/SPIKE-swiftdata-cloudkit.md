# Spike: SwiftData with CloudKit for the vault (stage S2)

Question (docs/02-DECISIONS.md, risk 1): can SwiftData synced through the CloudKit private database hold the
professional's vault, or must it fall back to Core Data with `NSPersistentCloudKitContainer`?

**Verdict: GO for SwiftData**, on every fact that can be established without an iCloud account and two phones. What is
left is a real-device checklist (task H3), below. The repository protocol (`ClientRecordRepository`) hides the choice, so
a fallback would change one folder, `Managers/Persistence/`.

## What was verified (all in `BelloHubTests`, run by `scripts/test.sh fast`)

| Fact | How |
|---|---|
| The schema is accepted with `cloudKitDatabase: .private("iCloud.com.bellohub")` | `VaultMigrationTests.cloudKitSchemaIsValid` creates the container; SwiftData's CloudKit validation did not throw |
| One entity, every attribute optional or defaulted, no relationships, no unique constraints | `schemaIsCloudKitShaped` inspects the schema |
| An additive change migrates on a real SQLite store with every row kept and decryptable | `additiveMigrationKeepsData` writes with a past schema, opens through a `SchemaMigrationPlan` |
| Clinical text never reaches disk in the clear | `sentinelsAreNotOnDisk` scans the database, its write-ahead log and the external-storage folder for 28 sentinels |
| Photo bytes in `externalStorage` are sealed; thumbnails decrypt | `photoBytesAreSealed` |
| A flipped byte, a wrong key, a locked app and a sealed field copied to another record are all detected | `tamperIsDetected`, `wrongKeyFails`, `lockedVault`, `sealedFieldCannotBeMoved` |
| Restoring with the 12 words opens records written before | `restoreFromRecoveryWords` |
| In-memory and SwiftData repositories behave identically | `Repository*ContractTests` run every case against both |

## Design decisions the spike led to

1. **One table.** Every record is a `VaultItem` told apart by `kindRaw`, with clear index columns, the non-sensitive
   JSON in `plain` and the sensitive part sealed in `sealed`. The CloudKit schema **only grows in production**
   (docs/02-DECISIONS.md, risk 4): with one record type, a new feature adds a `kindRaw`, never a CloudKit field.
   Relationships are ids and the repository cascades deletes itself, which is also what CloudKit requires.
2. **Whole-record conflict resolution.** Because a record is one JSON value, two devices editing the *same* record at the
   same time resolve last-writer-wins for the whole record, not field by field. Acceptable for one professional (the
   second device is usually idle); to be confirmed on two phones. The registration ledger is immune: one row per
   client id, only ever inserted, so syncing merges by union.
3. **Always pass an explicit CloudKit database.** SwiftData's default `.automatic` **turns CloudKit mirroring on by
   itself when the app has the iCloud entitlement**; the first migration test (default configuration) logged
   `NSCloudKitMirroringDelegate` errors. `VaultContainerFactory` passes `.none` or `.private(...)` every time, and CloudKit
   stays off (`.none`) until H2 (the schema deployed to Production).
4. **Encrypt before the store.** Sensitive properties are removed from the JSON and sealed with AES-GCM using a key that is
   never in CloudKit (D26); the associated data is `kind|id|field`, so a sealed field cannot be moved.
5. **Reading never hides data.** A record that cannot be read is left out of a list (and logged by id and kind only), but if
   *every* record of a kind is unreadable (the wrong key) the call fails, so a wrong key never looks like an empty vault.

## Restrictions found and how they are met

- Attributes must have defaults or be optional (met; tested). No `@Attribute(.unique)` (met; a duplicate id from a
  merge is resolved by the repository taking the first match). No ordered relationships (none). Large binary data uses
  `.externalStorage`, which CloudKit stores as an asset (`blob`).
- A CloudKit record is limited to about 1 MB without assets: `plain` and `sealed` stay small (a signature image is at
  most 64 KB, photos are external). To be asserted when the health-form import exists (S8).
- Enums are stored as raw strings with a safe fallback (`PersistedEnum`), so a value written by a newer app never crashes an
  older one and never widens who can see a photo (`PhotoVisibility` falls back to `professionalOnly`).

## What a simulator cannot show (checklist for two real iPhones, task H3)

Both phones: iOS 26 or later, the **same Apple ID**, iCloud Drive and Keychain on.

1. [ ] Build with `cloudKitContainerID: "iCloud.com.bellohub"` (a flag; off by default) and open the CloudKit Dashboard:
       the container shows one record type, `CD_VaultItem`.
2. [ ] Create a client, an appointment, a record and two photos on phone A; they appear on B within a minute.
3. [ ] Airplane mode on both; edit different records on each; reconnect: both edits survive.
4. [ ] Edit the **same** client on both while offline; reconnect: one edit wins, nothing is lost or duplicated
       (confirms decision 2).
5. [ ] Delete a client on A: her appointments, records and photos are gone on B; the registration ledger still has her
       entry on both (D42).
6. [ ] Fill the free 5 GB of iCloud (or use a test account at its quota): the app shows `iCloudFull` and keeps working locally.
7. [ ] Sign out of iCloud: the app shows `iCloudUnavailable` and keeps working locally.
8. [ ] Delete and reinstall the app on A: the vault, the recovery key state and the registration count come back.
9. [ ] Erase phone B, sign in, iCloud Keychain **on**: the vault opens without the 12 words. Repeat with iCloud Keychain
       **off**: the app asks for the 12 words and then opens the same records.
10. [ ] Record the time for 2,000 clients and 200 photos to reach phone B, and the iCloud usage, in `docs/PROGRESS.md`.
11. [ ] Deploy the schema to Production (task H2) before the first TestFlight build that enables CloudKit, and again for
        every build that changes the model (it should not, with one table).

## Fallback

If step 4 or 5 shows data loss that cannot be fixed in the repository, switch `Managers/Persistence/` to Core Data with
`NSPersistentCloudKitContainer` behind the same protocols. The domain types, the vault encryption and every ViewModel
stay unchanged.
