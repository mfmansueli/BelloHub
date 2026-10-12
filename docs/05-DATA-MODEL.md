# 05 · Data model: where every piece of data lives

Every modeling decision starts with one question: **does this datum need to be on the server for the client to book or answer?** If not, it **does not go to the server**.

| Layer | Technology | Holds | Who can read it |
|---|---|---|---|
| **A. The record (vault)** | SwiftData synced by CloudKit private database, sensitive fields encrypted by the app | Clients, health and consent, treatment records, photos, plans, incidents, services, availability, tags, quick replies, settings | Only the professional |
| **B. Operations (server)** | Firebase: Firestore, Functions, Storage, Auth | The minimum the public page and the client's management page need to work; sealed envelopes (opaque) | The professional through the app; each client her own booking through a secret link; nobody can read envelopes |
| **C. Browser (client)** | Memory only. Health answers are **never persisted** in the browser. Only non-clinical booking fields (service, chosen time, name, phone) may sit in `sessionStorage` so a refresh does not lose the booking; `localStorage` holds the chosen language and, per page, a trusted-device token with the e-mail it was issued for (returning clients skip the code, `10-WEB-BOOKING.md` section 3) | The client's in-progress booking | The client |

Layer A is reached **only** through `ClientRecordRepository`; layer B **only** through `BookingRepository` (`04-ARCHITECTURE.md` §3). Domain types in `Models/` are plain `Sendable` structs; the SwiftData `@Model` classes live in `Managers/Persistence/Schema/` and are mapped at the boundary.

---

## 1. Layer A rules (SwiftData + CloudKit)

**Implementation (stage S2):** the vault is **one SwiftData table**, `VaultItem` (`Managers/Persistence/Schema/`), with a `kindRaw`, a few clear index columns, the non-sensitive JSON and the sealed sensitive part, instead of one `@Model` per type below. The types below are the *domain* structs in `Models/`; each one declares which of its properties are sealed (`VaultStorable.sensitiveKeys`, pinned by a test against the table in this section). Reason: the CloudKit schema only grows, and a new kind of record is then a new `kindRaw`, not a CloudKit field (`docs/spikes/SPIKE-swiftdata-cloudkit.md`).

**Restrictions that apply to every `@Model`** (verify each in stage S2 and write the result in the spike report; do not assume):
- Every attribute has a default value or is optional. No `@Attribute(.unique)`. Relationships are optional. No `.deny` delete rule. No ordered relationships (store `position: Int`). Large binary data uses `@Attribute(.externalStorage)`. No custom `Codable` types the schema cannot represent (store `Data`).
- The CloudKit schema **only grows** in production: never remove or rename a field; add fields; deploy the schema to Production before each release that changes it.
- Conventions: `id: UUID`, `createdAt`, `updatedAt` (UTC), names in English, enums stored as `String` raw values with a fallback case for unknown values (forward compatibility).

**Sensitive-field encryption (D26).** The repository encrypts these with `VaultFieldCodec` (AES-256-GCM, per-record random nonce, associated data = model name + record id + field name) and stores `Data`:

| Model | Encrypted fields |
|---|---|
| `HealthForm` | all `answers`, `minorName` |
| `ConsentRecord` | `label`, `note`, `document` (photo or file of the real signed paper) |
| `TreatmentRecord` | `notes`, `technique`, `productsUsed`, `result` detail text, `reaction`, `aftercare`, `nextSessionSuggestion`, `nextVisitReminder`, `fieldEntries` |
| `RecordCorrection` | `oldValue`, `newValue`, `reason` |
| `Incident` | `symptoms`, `actionTaken`, `followUp` |
| `Client` | `importantNote`, `allergies`, `sensitivities`, `preferences`, `recurringRequests`, `stopReason` |
| `Photo` | `image`, `thumbnail` (encrypted file bytes in `externalStorage`) |
| `Appointment` | `privateNote` (if present) |
| `TimeBlock` | `reason` |
| `SavedOption` | `name` (a saved sensitivity can be health information) |

**Not encrypted** (needed for sorting, queries, notifications, search): names, phone numbers, dates, service names, statuses, tags, counts. Free-text clinical search works by decrypting in memory over the working set (fine to a few thousand records) and is limited to what the professional has loaded; document the limit.

**Deleting** a client deletes her appointments, records, corrections, incidents, photos and consents locally (CloudKit propagates) and asks the server to delete any `bookings`, `portal` and `inbox` items tied to her.

### Profile and business
- **ProfessionalProfile** (one): `displayName`, `businessName`, `slug`, `city`, `countryCode`, `timeZoneID`, `currencyCode`, `appLocaleID`, `bookingLocaleIDs`, `whatsappE164`, `bio`, `photo`, `professions: [String]`, `clientTerm`, `inboxKeyID`.
- **Service**: `name`, `category`, `durationMinutes`, `priceAmount: Decimal?`, `priceDisplay` (`show`, `startingFrom`, `onRequest`, `hide`), `followUpWeeks`, `remindBeforeAfterPhotos`, `aftercareTemplate`, `isActive`, `position`, `contraindications: [String]`, `requiresPatchTest`, and the visit's shape (D56, all optional, default 0; the vault keeps them as one optional `timing`): `prepMinutes` and `cleanupMinutes` (0 to 60, blocked before and after, not in the visible length or price), `processingMinutes` and `processingStartMinutes` (a stretch inside the visit, starting that many minutes after it begins, while she is free for another visit).
- **AddOn**: `name`, `minutes`, `priceText?`, `isOffered`, `position`. **Product**: `name`, `note`, `sharedWithClient` (default false); no stock, no sale price.
- **AvailabilityRule** (`weekday`, `startMinutes`, `endMinutes`), **BreakRule** (`weekday?`, `startMinutes`, `endMinutes`, `label`), **DayOff** (`startDate`, `endDate`, `kind`), `bufferMinutes` on the profile, and with it `slotStepMinutes` (10, 15 default, 20, 30, 60, or 0 = match the service, D56) and `compactDay` ("Keep my day compact", default on, D56).
- **TimeBlock**: `startsAt`, `endsAt`, `reason` (private). Produces a busy block on layer B (no reason). Cancellations it causes have `cancelledBy = professional` and never count as late cancellations or no-shows.
- **Tag** (`name`, `colorToken`), **QuickReply** (`title`, `text`), **Credential** (`title`, `institution`, `year`, `registrationNumber?`, `certificatePhoto?`, `showOnBookingPage`), **RecordFieldTemplate** (`key`, `label`, `kind`, `isEnabled`, `position`).
- **CancellationPolicy**: `freeWindowHours` (2, 12, 24, 48, 72), `clientCanReschedule`, `maxReschedules?`, `afterWindowCancel` (`allow`, `message`), `afterWindowReschedule` (`request`, `message`), `askConfirmation`, `graceMinutes` (5–20).
- **NoShowPolicy**: `isOn`, `limit` (1–5), `action` (`tell`, `approveNewBookings`, `pauseOnline`), `lateCancelCounts`.
- **BookingPageSettings**: `acceptingBookings`, `pausedUntil?`, `confirmNewClients`, `maxGuests` (0–2).
- **BookingSetup.location: BusinessLocation?** (2026-10-11, "Where you work"; optional, absent in older setups):
  `street` (street and number), `postalCode`, `city`, `countryCode` (starts as the business region), `directions`
  (how to find us), `visibility` (`confirmedClients`, the default, or `bookingPage`). Not clinical; stored in the clear
  with the booking setup. `BusinessLocationFormat` writes the lines and the Apple Maps / Google Maps links that are
  published.
- **QuickReply** text may use `{address}` besides `{name} {service} {date} {time} {link}`; built-ins she never edited
  are upgraded once to the current wording (`QuickReplyUpgrade`).
- **NotificationPrefs**: toggles per alert kind, `quietHours?` (`from`, `until`), `dailySummary`, `clientRemindersEnabled`, `birthdaysEnabled`, `recordsToWrite` (2026-10-12; an evening count of visits waiting for their record; missing reads as on). Urgent alerts (client running late, same-day cancellation) ignore quiet hours.
- **RecordFieldSetting** (in `RecordTemplate`): `profession`, `key`, `customName?`, `isOn`, `kind`, `options`, `unit?`, `isRequired` (2026-10-12: needed to finalize, never to save a draft), `serviceIDs` (2026-10-12: the services the field is asked for; empty = every service). Both new fields are optional in storage and read as false / empty.
- **RecordMark** is never stored: Home, Alerts, notifications and the client list read every record reduced to its links and state (`id`, `clientID`, `appointmentID?`, `serviceID?`, `serviceName`, `status`, `createdAt`, `performedAt?`) through `TreatmentRepository.recordMarks()`; no clinical text leaves the repository that way.
- **LocalePrefs**: see `07-LOCALIZATION.md` §3 (`businessLocalizationID`, `regionCode`, `currencyCode`, `weekStart`, `use24Hour`, `bookingLocaleIDs`). **RegionPreset** is bundled data (`16-MARKETS.md` §1), not stored per user.

### Clients
- **Client**: `name`, `phoneE164?`, `email?`, `photo?`, `tags`, `source` (`bookingLink`, `import`, `manual`, `referral`), `birthday?`, `isArchived`, `onlineBookingStopped`, `remindersEnabled`, plus the encrypted fields above.
- **HealthForm**: `client`, `formVersion`, `answers` (key → value; includes isotretinoin or peel in the last 6 months), `filledBy` (`client`, `professional`), `isForMinor`, `submittedAt?`, `importedFromItemID?` (dedup). No consent text, agreement or signature travels with it (D55).
- **ConsentRecord** (D55; consents are the professional's own business; the app only records their status): `client`, `kind` (`treatment`, `photos`, `guardian`, `other`; in the clear, it is the index), `label?` (free, hers), `isSigned`, `signedAt?` (only while signed), `createdAt`, `note?`, `recordID?` (2026-10-12: the visit the document belongs to, optional; a visit's record never depends on it), `document?` (encrypted photo or file of the real signed paper: `kind` photo or file, `fileName?`, `contentType`, `data`, `thumbnail?`; a photo goes through the photo pipeline, a file is at most 10 MB). The app writes no consent text; a `photos` record she marks signed is what drives `Photo.visibility`. The vault kind stays `consent`: a record from before D55 (text version, language, typed signature) reads as signed on its date, the old fields ignored.
- **SessionPlan**: `client`, `name`, `totalSessions`, `intervalWeeks`, `startDate`, `currentIndex`.

### Agenda
- **Appointment**: `client`, `service`, `startsAt`, `endsAt`, `totalMinutes`, `status` (`booked`, `confirmed`, `completed`, `cancelled`, `noShow`), `cancelledAt?`, `cancelledBy?`, `isLateCancellation`, `origin` (`bookingLink`, `manual`), `bookingID?` (server id), `visitType` (`treatment`, `touchUp`, `reactionCheck`), `linkedAppointment?`, `addOns`, `guests` (name; same service, in sequence), `sessionPlan?`, `rescheduleCount`, `reminderSentAt?` (the reminder chat was **opened**; it proves neither sending nor delivery), `reminderMarkedSentAt?` (routine-a, 2026-10-11: she said she sent it herself; optional and additive, older visits decode as nil; both cleared by a reschedule), `clientConfirmedAt?`, `lateByMinutes?`.
- **WaitlistEntry**: `client?`, `nameIfNoClient`, `phoneE164`, `serviceID?`, `dayFrom`, `dayTo`, `status`, `offeredAt?`.
- **RescheduleRequest**: `appointment`, `requestedStart`, `note?`, `status`. The current slot stays reserved until she answers.
- **MessageLog**: `client`, `channel`, `template`, `openedAt`. Records that the chat was **opened** with the text ready.

### Treatment record
- **TreatmentRecord**: `client`, `appointment?`, `service`, `createdAt`, `performedAt?` (the day the treatment happened, set by her; nil on records from before it existed), `status` (`draft`, `finalized`; missing reads as `finalized`), `finalizedAt?`, `lockedAt` (`.distantFuture` while a draft, `finalizedAt` + 24 h once finalized; records from before drafts keep `createdAt` + 24 h), `source` (`voice`, `manual`), `result` (`great`, `good`, `neutral`, `reaction`), `aiAssisted`, plus encrypted text fields. **After `lockedAt` it changes only through `RecordCorrection`.** A draft is never locked and is never corrected; a finalized record never returns to draft (`TreatmentRecordSaveRule`).
  - **Visit date shown on screen** (`RecordVisitDate`): `performedAt`, else the linked appointment's start, else none (the screen says the visit day was not noted and shows when it was written). Nothing is backfilled into old records.
  - **One record per appointment**: a new record for an appointment first looks for a record with that `appointmentID` and opens it instead (`RecordForAppointment`).
- **RecordCorrection**: `record`, `createdAt`, `fieldKey`, encrypted old/new/reason. Never deleted.
- **Incident**: `client`, `record?`, `occurredAt`, `severity`, encrypted text; locks like a record.
- **Photo**: `client`, `record?`, `takenAt`, `kind` (`before`, `after`, `progress`), `visibility` (`professionalOnly`, `shareWithClient`, `portfolio`), encrypted `image` and `thumbnail`.
- **Voice**: audio is **not stored** after review (default); the transcript is a draft the professional reviews, then the structured result is saved and the draft is deleted.

### Registration ledger (D42)
- **RegistrationLedgerEntry**: `clientID`, `registeredAt`. Exactly one per client id ever registered, written the first time a client id is saved. **Never deleted, not even when the client is deleted** (it holds no name, phone or any personal data, only an id and a date). The number of entries is the cumulative registration count; the first 10 are free. Synced by CloudKit, so the count follows her Apple ID across devices and reinstalls; the server holds the authoritative copy (layer B, `accounts/{uid}.registrations`) and the app uses the larger of the two.

### Derived, never stored
- **ClientHabits**: `visits`, `cancelled`, `noShows`, `lateCancellations`, `returnsEveryWeeks` (median interval), `usualPeriod`, `reminderResponseDays`, `mostBookedService`, `source`. The cancellation rate shows only with ≥ 4 completed visits. Definition: rate = (cancellations by the client + no-shows) ÷ past appointments among the last 10; "cancels often" at ≥ 30 %. A cancellation made by the professional is excluded; a forgiven no-show is excluded.
- **FollowUp**: last completed visit ≥ the service's `followUpWeeks` (carries `intervalWeeks` for the reason she reads). **WinBack**: no visit for ≥ 60 days.
- **FollowUpQueue** (routine-a, 2026-10-11): reminders, visits left with "Finish later", check-ins after a visit of today or yesterday, returns due, clients not back and birthdays, grouped by client, each with a reason built from her own data (`FollowUpReason`, no clinical inference) and a `MessageDeliveryState` (ready to send, conversation opened, marked as sent by her).

### Local to this iPhone (UserDefaults, per user, never synced or sent)
Ids, dates and flags only, nothing clinical; removed with the account (`DefaultsKey.prefixesClearedOnAccountDeletion`).
- **OnboardingProgress**: the unfinished setup's step and draft (her name, business name, professions, first service), so it resumes after a relaunch; cleared at the end of the setup.
- **FollowUpDecision** by occurrence: `snoozedUntil?`, `dismissedAt?`, `markedSentAt?` (a new visit is a new occurrence).
- **VisitClosing** by record id: `clientID`, `appointmentID?`, `serviceName`, `recordCreatedAt`, settled steps (`photos`, `aftercare`, `nextVisit`), `isDeferred` ("Finish later"). The record itself, its lock and its corrections are unchanged.
- **Interface language** (`interface.language`): "system" or one of the fourteen; device-wide, kept when the account goes.
- **FreeSlots** (D56): availability − appointments − breaks − days off − blocks − buffer, respecting the business time zone and DST. Candidates are the slot grid plus starts anchored against every visit, break, block and stretch edge; the blocked stretch of a visit is prep + visit + clean-up, minus its processing stretch. The result is two lists: every free start, and the *recommended* ones that leave no dead fragment (free time shorter than her shortest offer plus the buffer), with the honest fallback per gap. Pure, mirrored line by line by `functions/src/lib/freeSlots.ts`.

### Photos pipeline
Capture with the in-app camera; **never** write to the camera roll. Importing from the library is allowed. On save: longest side ≤ 2048 px, HEIC or JPEG around 400 KB, 320 px thumbnail, EXIF (especially location) stripped, then encrypted. Photos count against her iCloud quota; show `iCloud full` when CloudKit reports quota errors.

---

## 2. Layer B (Firebase)

Region per D29. Collections (details, rules and functions in `11-BACKEND-FIREBASE.md`):

| Collection | Content | Written by | Read by |
|---|---|---|---|
| `accounts/{uid}` | phone, `slug`, country, `dataRegion` (`eu` in v1, D29), locale, mirrored plan state, **`registrations {count, freeLimit}` (D42)**, deletion state, `inboxKeyring` public keys | Function and the account owner (non-sensitive fields only) | Owner |
| `accounts/{uid}/registrations/{clientId}` | `registeredAt` only (an opaque client id, no personal data); created once per client id by `reserveRegistration`, never deleted by a client delete | Function only | Owner |
| `publicProfiles/{slug}` | what the public page shows: name, bio, city, photo, public credentials, services (name, duration, price text only if she chose to show it, and the extra and processing minutes of D56), add-ons, time zone, currency, locales, **rules text per locale**, policy values, `inboxKey` (public) | The app (publishes) | Anyone |
| `businessLocations/{uid}` | where she works as the app formatted it (`lines`, `directions?`, both map links) and `visibility` (`confirmed` or `public`); a copy without `visibility` goes into `publicProfiles/{slug}.location` only with `public` | Function (from `publishProfile`) | Functions only (getBooking for a confirmed booking, e-mails, `getIcs`) |
| `availability/{uid}` | weekly rules, breaks, days off, buffer, slot interval and compact day (D56), **busy blocks (start/end only and the visit's extra and processing minutes, no names, no reasons)** | The app | Functions |
| `bookings/{id}` | `ownerUid`, service, add-ons, guests count, start, end, status, **client name, phone (E.164), optional email, locale**, `manageTokenHashes` (at most five), `ownerLinkMintedAt` (when her app last asked for the client's link, `mintManageLink`; the token is derived, never stored), timestamps | **Functions only** | The owner; the client through a function with her token |
| `inbox/{uid}/items/{itemId}` | **sealed envelope** (opaque), `kind`, `bookingId`, `createdAt`, `expiresAt`, size | Function (client submits) | The owner |
| `portal/{token}` | what the professional chose to publish to the client: upcoming visits, aftercare text, shared product names | The app | The client through a function |
| `rescheduleRequests/{id}`, `waitlist/{id}` | request data (name, phone, requested time, note) | Functions only | The owner |
| `devices/{uid}/tokens/{id}` | push tokens | The app | Functions |

What the server **does** know: client first name or name and phone for the people who book, service, time, status, and the fact that a sealed form exists for a booking. It **never** knows: health answers, consent records, notes, photos, allergies, habits, tags, anything from the record.

Time zones: store UTC instants plus the business `timeZoneID`; render in the **business** time zone on the web ("15:00 in São Paulo") and tell clients if their device is in a different zone.

Retention and deletion: D30. Identity: the server account is the **phone**; the record belongs to the **Apple ID**. Warn about this in onboarding and `Privacy`.

---

## 3. The sealed mailbox (summary; full spec in `06-PRIVACY-SECURITY.md` §3)

1. The professional's app publishes her **inbox public key** in `publicProfiles/{slug}.inboxKey` with a `keyId`.
2. The client's browser seals the health form (and later a check-in photo) with that key and submits an **envelope**.
3. A Function stores the envelope with a TTL and sends a silent push.
4. The app downloads, decrypts with the inbox private key, writes into the vault (`importIntake`, idempotent by `itemId`), then calls `acknowledgeMailboxItem`; the server deletes it.
5. If it is never acknowledged, the 30-day TTL deletes it.

---

## 4. Sample data for previews and tests

Use the prototype's demo set (`design/PROTOTYPE-NOTES.md` §3): Maria (esthetician, São Paulo), twelve clients, three appointments today, the habits for Ana and Beatriz, the demo policy, credentials and quick replies. Build `Fixtures/` (`#if DEBUG`) for it, localized by locale where names and city make sense (a pt-PT fixture set in Lisbon, es-MX in Mexico City, es-ES in Madrid, en-US in Austin) so locale bugs surface in previews.
