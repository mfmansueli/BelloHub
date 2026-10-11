# 01 · Product

## What it is

An iPhone app for **independent** beauty and aesthetic-health professionals. She organizes her agenda and the app **remembers each client**: a living record with visit history, before/after photos, health and consent, habits and session plans. Clients book from a web link in any browser; no app, no password.

It is not a clinic system and not a salon marketplace.

## Who

- **The professional** (the buyer): works alone or nearly alone, phone in hand, full head, WhatsApp as her agenda, photos mixed with her personal camera roll. **iPhone only.**
- **Her client**: books, changes, cancels and fills in her health form from a web page, on **any** phone, tablet or computer, usually opened from a WhatsApp link (in-app browsers matter, see `10-WEB-BOOKING.md`). She pays nothing.
- Launch markets: Brazil, Portugal, Mexico, Spain, United States. The app is built multi-country from day one (`07-LOCALIZATION.md`).

## Product rules (non-negotiable)

1. **No financial operations.** No payment, deposit, invoice, commission, cash box, revenue, price-bearing package, "client value". Prices appear only as service information and only if the professional chooses to show them (`priceDisplay`). The Bello Hub subscription (StoreKit 2) is separate and is the only charge: the first 10 client registrations are free, then one paid plan (D42).
2. **The record belongs to the professional.** It lives on her iPhone and in her iCloud. The Bello Hub team never sees records, photos or health information (`05-DATA-MODEL.md`, `06-PRIVACY-SECURITY.md`).
3. **Records lock 24 hours after creation.** After that every change is a **logged correction** (who, when, what), never a silent edit.
4. **Client habits are private to the professional.** The client never sees them. The cancellation rate shows only after 4 completed visits (absolute numbers before). Neutral language: "habits", never "reliability" or "bad client".
5. **Lock-screen alerts never show a client name.** Generic text only ("New booking", "A client"). No clinical content in any notification, WhatsApp text or email.
6. **AI always goes through review.** The app organizes what the professional said. It never diagnoses, never adds a product or technique she did not say, and nothing is saved without her review.
7. **No decorative theme.** No passport, spa or travel metaphor. Direct names, warm soft colors, space, calm motion. The charm is in the care for detail and friendly microcopy.
8. **A client can ask for a copy or deletion of her data**, and the professional serves it from the app (`Privacy`, `Cl-7-MyData`).
9. **Messages to clients open WhatsApp with the text ready** (the professional taps send). The app does not send WhatsApp on its own in v1. See D31 for the exact channel plan, including the server-sent items.

## Pains it solves (map to screens)

| # | Pain | Answer | Screens |
|---|---|---|---|
| 1 | Clients vanish and she does not notice | Follow-up by service interval, "haven't returned", ready message | `FollowUps`, `WinBack`, `Home`, `Clients` |
| 2 | No-shows and last-minute cancellations leave holes | Waitlist offers the freed slot; no-show protection; visible cancellation rules | `Waitlist`, `NoShowPolicy`, `CancelPolicy`, `Bk-1-Page` |
| 3 | Fear of error: no record, a reaction becomes a legal problem | Record with edit trail, 24 h lock, signed consent, incident log | `RecordHistory`, `Incident`, `ClientHealth`, `ExportRecord` |
| 4 | Photos and data mixed into her personal phone | Photos only inside the app, consent per photo | `Camera`, `Tx-6-Photos`, `Privacy` |
| 5 | Proving the result | Before/after side by side, slider, timeline | `Tx-6-Photos`, `ClientProfile` |
| 6 | Repeating the same questions | Profession-adaptive record, "Before you start" | `Onb-6b-Record`, `RecordTemplate`, `BeforeYouStart` |
| 7 | Aftercare forgotten | Aftercare and skin check-in sent to the client | `Tx-5-Saved`, `Cl-2-Portal`, `Cl-5-CheckIn` |
| 8 | Full head, working alone | Voice record organized by on-device AI; quick actions; ready messages | `Tx-1-Register`…`Tx-4-Review`, `Home`, `QuickReplies` |
| 9 | Unpredictable day | Home with the day and free slots of the week (no money) | `Home`, `WeekGlance` |
| 10 | Hostage of WhatsApp | Booking link and QR, ready messages sent from her own number | `ShareLink`, `BookingSettings`, `MessageClient` |
| 11 | Recognition as a professional | Credentials on the public page, record and consent | `Credentials`, `Bk-1-Page` |

## Voice and microcopy

Warm, direct, sentence case, no diminutives, no forced humor. "Your day is clear." "Could not save. Check your connection and try again." Errors say what happened and how to fix it, without apologizing. An action keeps one name through the flow (the "Publish" button produces "Published"). The prototype texts are the English source; the five locales are written per `07-LOCALIZATION.md`, not machine-literal.

## Out of v1

Team (several professionals; the `Team` screen exists and shows "later"), iPad, Mac, Android, Windows, web app for the professional, any financial feature, public marketplace or reviews, automated WhatsApp sending (a provider interface exists and is disabled until a human configures it, D31), cloud AI (feature flag only, D23).
