# Client messages and location (agent notes)

Task: `docs/tasks/client-messages-and-location.md` (owner, 2026-10-11). Single agent on `build/v1`, from `9fc0e0e`.

## 1. Map and proposal (written before any code)

### 1.1 Every place a link enters a client-facing message

**App (the professional sends it herself, D14):**

| Builder | Where | `{link}` today |
|---|---|---|
| Quick replies (3.6 "Message <client>": Confirm appointment, Running late, Reschedule, Aftercare, Check-in, Come back soon, her own) | `MessageClientViewModel.text` → `AppointmentMessageComposer` → `QuickReplyRenderer` | `BookingLink(slug:).display` = `bellohub.app/maria` (no scheme). In Arabic wrapped in LRI/PDI isolates |
| Reminders ready (Home, Alerts, follow-up queue) | open the same 3.6 sheet (`AgendaSheet.message`, `FollowUpAction`) | same as above |
| Built-in texts | `BuiltInQuickReply` (catalog `quickReplies.default.*.text`, batch `s5-booking.json`), stored in the vault when she first opens the list, hers to edit afterwards | Confirm: `use {link} to change it.` (link glued mid-sentence); Reschedule `new times: {link}`; Check-in `one tap: {link}`; Come back `save a time? {link}` |
| Follow-up, win-back, birthday | `ClientMessageViewModel` → `ClientMessageComposer` (uses her "Come back soon" reply) | `display` form |
| Cancel by her (3.4) | `CancelAppointmentViewModel` → `appointment.message.cancelled` | value passed but the text has no `{link}` |
| No-show note, running late | `NoShowMarkViewModel`, `RunningLateViewModel` | `link: nil`, texts have no link |
| Quick reply editor preview, LanguageRegion preview | `QuickRepliesViewModel.sampleValues`, `LocalePreview` | `display` form; `LocalePreview` hard-codes `bellohub.app/<slug>` |
| Share link screen | `ShareTexts.whatsAppGreeting` (`...book with Maria here: bellohub.app/maria`), `instagramBio`, `shareMessage` + `ShareLink(item: link.url)` | greeting and bio use `display`; the share sheet item is the full URL |
| "Suggest another time" (2.10) | `SuggestTimeSheet` `ShareLink(item: suggestionURL, message:)` | full URL item (`<web>/<slug>/time?offer=<key>`) |
| Waitlist offer (2.9) | `WaitlistViewModel.offerAsync` | **no message at all**: the hold key the server returns is dropped (`case .offered(_, let expiresAt)`), so the client never gets the link (docs/10 section 3 says "opens WhatsApp with a ready message and a one-time hold link") |
| Booking link card, QR caption, table card, Account row | `BookingLinkCard`, `ShareLinkView`, `TableCardView`, `AccountContentView` | `display`: she reads these herself (or prints them); they stay `display` |

**Server:**

| Builder | Where | Link |
|---|---|---|
| Confirmation e-mail (`bookingConfirmed`) | `createBooking` → `sendBookingEmail` | `${webBaseUrl}/m/<token>`, on its own line (the raw token exists only in that call) |
| Request received (`bookingPending`) | same | manage link on its own line |
| Approved (`bookingApproved`) | `respondBookingRequest` | **no link** in the text ("use your personal link" without one); an unverified request approved gets `bookingConfirmed` with a fresh token |
| Moved (`bookingMoved`) | `moveBookingByOwner`, `respondRescheduleRequest` | **no link** in the text |
| Declined, cancelled by her | `respondBookingRequest`, `cancelBookingByOwner`, `suggestBookingTime` (no e-mail) | `${webBaseUrl}/<slug>` on its own line |
| HTML part | `emailHtml.ts` | bare `https://` becomes `<a>`; **bug:** in Arabic `fillTemplate` wraps the link in FSI/PDI and `URL_PATTERN` (`[^\s<>"']+`) swallows the PDI into the `href` |
| WhatsApp templates (disabled, H13) | `whatsAppTemplates.ts`, `sendReminders` | `link` parameter = `${webBaseUrl}/m/<token>` (full) |
| ICS from the server | `getIcs` → `lib/ics.ts` | `URL:` and `DESCRIPTION` carry the **manage** link (contradicts D50; the web never calls `getIcs`) |
| ICS in the browser | `web/src/lib/ics.ts` (`CalendarSheet` on Bk-8 and Bk-9) | page link (D50), `LOCATION` = `profile.city` (the app never publishes `city`, so it is always absent) |
| Push | `push/fcmMessage.ts` | generic text, no link |
| `docs/strings/message-templates.json` | documentation of the 16 kinds (Meta template bodies) | `... use your link: {link}` at the end of the sentence |

`BookingLink.display` (`bellohub.app/maria`) is what every app message carries. WhatsApp, iMessage and SMS do not
reliably turn a scheme-less address into a link, which is the owner's point 3.

### 1.2 Token machinery

- Manage tokens: 22 base64url characters (128 random bits, `Random.token()`); only `sha256("manage:" + token)` is stored
  in `bookings/{id}.manageTokenHashes` (`lib/bookingAccess.ts`); `withNewTokenHash` keeps the last five
  (`MAX_MANAGE_TOKENS_PER_BOOKING`), dropping the oldest. A token opens the booking until `purgeAt` (visit end + 7 days).
- Minted by: `createBooking` (and a replay with the same idempotency key), `findBookings` (one more per found booking),
  `respondBookingRequest` when it approves an unverified request, and `sendReminders` (WhatsApp automation only: one
  more valid link per reminder, written with `reminderSentAt`). Nothing else can produce one, so **the app cannot build
  `/m/{token}`** today.
- Owner callables load a booking with `loadOwnedBooking` (someone else's id is `NOT_FOUND`), rate-limit with
  `consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls)` and log ids only.

### 1.3 What `/m/{token}` shows first

`ManagePage.tsx`: title "Your appointment" + status chip, a pending reschedule notice, the booking card (date, time,
service, with), the pending notice, "Will you be there?", "Running late?", then the actions list (Add to calendar,
Reschedule, Cancel) further down, without a heading. "Change or cancel" is never said as such.

### 1.4 Profile fields and publishing payloads

- `PublishProfileRequest` (app) sends: name, business name, region, zone, currency, locales, credentials, services,
  add-ons, booking switches, policy, rules texts, inbox key, intake. It does **not** send `city`, `bio`, `photo` or
  `whatsappE164`, although the contract has them (so the page never shows a city, and the D58 "Confirm on WhatsApp"
  path never appears for a real professional: an open item outside this task, reported, not changed).
- `PublicProfileInputSchema` (`contracts/profile.ts`) is strict: an unknown key is `INVALID_ARGUMENT`.
- `publicProfiles/{slug}` is world-readable by rule (`allow get: if true`), so anything stored there is public.
  Function-only data of the page lives elsewhere (`intakeForms/{uid}`).
- The app keeps the booking page settings in `BookingSetup` (vault, Codable, edited through `BookingSetupEditor` by the
  Booking settings screens) and publishes through `PublishingService` → `PublishPayloads.profile`.

### 1.5 Final design

**Point 1: full links.** One pure owner in the app: `ClientLinkText` (`Models/Messages/`): a client-facing link is
`url.absoluteString`, and the rule that places it: on its own line, with any closing punctuation that was glued after it
dropped and no bidi isolates around it (the line is its own paragraph, so it cannot reorder Arabic text, and an isolate
character next to a URL can end up inside the detected link, which is what happens in the e-mail HTML today).
`QuickReplyRenderer` applies the placement to `{link}`, so the texts she already saved also come out right; the
built-in "Confirm appointment" and "Reschedule" texts are rewritten (link last, own line) and a stored built-in whose
text is still the previous default is upgraded once (the old wording stays in the catalog as `...text.v1` keys only for
that comparison). `display` stays for what she reads herself (link card, QR caption, table card, Account row,
Instagram bio line: Instagram never makes a bio link clickable, its own link field takes the full URL from "Copy link").
The WhatsApp greeting on the share screen, the editor and language previews use the full URL. The waitlist offer gets
its message (the hold link is kept and a "Send" action opens WhatsApp with the offer text). Server: the HTML part never
takes an isolate into an `href`, `getIcs` carries the page link like the browser's file (D50: no manage token in a
calendar), and `docs/strings/message-templates.json` puts `{link}` on its own line.

**Point 2: the exact link.** New owner callable **`mintManageLink`**:

```ts
mintManageLink: req { bookingId: string }
                res { url: string /* <web>/m/<token> */; expiresAt: Instant /* the token's end: visit end + 7 days */ }
```

- Only her own booking (`NOT_FOUND` otherwise), only while it is `confirmed` or `pendingApproval` and has not ended
  (`BOOKING_NOT_ACTIVE` otherwise: a cancelled or past visit is not something to change).
- Reuses the token machinery: the new token's hash joins `manageTokenHashes` through `withNewTokenHash` (at most five
  valid, the oldest dropped). Nothing else is stored but `ownerLinkMintedAt` on the booking.
- **Idempotent for 30 minutes without keeping the token:** the token is derived, not drawn:
  `base64url(HMAC-SHA256(pepper, "ownerManageLink\0<bookingId>|<mintedAtMs>")[0..16])`. A second call inside the
  window recomputes the same token from `ownerLinkMintedAt` and returns it when its hash is still in the list (it is not
  if five newer links pushed it out, or if the pepper changed: then a new one is minted). Opening the sheet twice or
  tapping send after opening it does not burn the client's other links.
- Rate limit 60 per hour per owner (`manageLinkOwner`); logs `manageLink.minted` with uid, booking id and
  `reused`, never the token or the URL; no audit document (nothing personal to record).
- API.md 6.3, schemas, emulator tests (own booking, someone else's, inactive, idempotent, five-token cap, rate limit,
  the link opens `getBooking`).

App: `InboxRepository.mintManageLink(bookingId:)` (Remote, Offline = `notPublishedYet`, UI-test server). A
`ClientLinkService` (`Managers/Messaging/`, created with the inbox services, read from the environment) caches a minted
link per booking for 25 minutes (inside the server window). The pure `ClientLinkPlan` decides: a visit with a
`bookingID` that still holds time and has not ended asks for the manage link; anything else uses the booking page. The
3.6 sheet asks when it opens, shows "Preparing the link" (the Open button waits for it), and says in a quiet line which
link the message carries: her own link to change or cancel, or the booking page because the visit was added by hand,
because the iPhone is offline, or because the link could not be prepared. Other messages (cancel, no-show, late,
follow-up, birthday) keep the booking page or no link, as today.

`/m/{token}`: the actions move up, right after the booking card, under a "Change or cancel" heading; a Playwright test
opens the page with WhatsApp's and Instagram's in-app user agents and storage blocked.

**Point 3: the address.**

- Where it lives: `BookingSetup.location: BusinessLocation?` (vault, optional, so old data reads as nil):
  `street` (street and number), `postalCode`, `city`, `countryCode` (default: the business region), `directions` (how
  to find us: floor, bell, landmark), `visibility`.
- **Visibility:** `confirmedClients` (**default**: confirmation e-mail, confirmation page, manage page, ICS, `{address}`)
  or `bookingPage` (also on the public booking page). Nothing is published until she saves an address.
- One pure owner `BusinessLocationFormat` (`Models/Business/`): the display lines (postal code before or after the city
  by country, a small table), the one-line form, and the two map links built from the text, no SDK and no geocoding:
  `https://maps.apple.com/?address=<q>` and `https://www.google.com/maps/search/?api=1&query=<q>`.
- **Published contract** (`publishProfile`, optional):
  `location?: { lines: string[] /* 1..3, <= 120 */; directions?: string /* <= 300 */; maps: { apple: string; google: string }; visibility: "confirmed" | "public" }`.
  The app is the only one that formats an address; the server and the page print the lines and the links it published.
  The server checks the map links' prefixes and lengths.
- **Storage:** always in the function-only `businessLocations/{uid}` (no client read rule); with `public` a copy without
  `visibility` also goes into `publicProfiles/{slug}.location`. Publishing without `location` removes both. Account
  deletion removes the document.
- **Who sees it** (server rule `lib/location.ts`, one owner): `public` → everyone; `confirmed` → only a booking in
  `confirmed` status (so a request waiting for her does not reveal a home address).
- Shown in: `getBooking.location` (manage page and the confirmation page, which already reads the booking back),
  `getPublicPage.profile.location` (public only), the e-mails `bookingConfirmed`, `bookingPending` (public only),
  `bookingApproved`, `bookingMoved` (14 localizations, an address block after the date), both ICS builders (`LOCATION`
  = the one-line address, the map link in `DESCRIPTION`), and the quick-reply word **`{address}`** (her saved address
  lines, the "how to find us" note and the Google Maps link, which opens on any phone; when she has no address the word
  and its line disappear), used by the built-in Confirm and Reschedule texts.
- Settings: Booking settings gets a "Where you work" section with one row that pushes the "Where you work" screen
  (fields, country menu, the two visibility choices, a live preview of what the client sees with both map links, Save,
  Remove).

**Point 4: e-mail polish.** The HTML part keeps being built from the text, with the web tokens (ivory background,
graphite text, orange `rose-text` link), plus a button-looking "Change or cancel" link (orange `action` fill, ink label)
for the e-mails that carry the personal link, the address block, and an optional `EMAIL_REPLY_TO` parameter (empty by
default; when set, Resend gets `reply_to`). No images, no tracking.

**Approved and moved e-mails get the exact link too:** both now mint one more manage token (the same five-link cap) and
the text carries it on its own line.

**Deploy:** functions and hosting both change.
