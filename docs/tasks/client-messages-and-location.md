# Task: client messages with clickable exact links, and the store's location

Queued by the owner on 2026-10-11 after the first real e-mail test (`bellohub.app`, Resend, Outlook).
One agent, `model: opus`, `effort: high`. Commit first, test after. Branch `build/v1`, main checkout.

## What the owner said (verbatim, Portuguese)

1. "Tambem vi que o email de confirmacao de um agendamento nao esta exibindo os detalhes de onde eh a loja. Seria
   interessante ter esses detalhes."
2. "E os links tem q ser clicáveis e levar direto ao site exato para a pessoa conseguir fazer a mudança ou cancelar."
3. "Em várias partes do app q vc vai enviar mensagem pro cliente os links são passados como texto e não são
   clicáveis, nessa página tem exemplos q acontecem…" (screenshot of the "Message <client>" sheet: Confirm
   appointment, Running late, Reschedule, Aftercare, Check-in, ...; the messages carry the link as text).

## What we know

- The e-mails sent by the server (`firebase/functions/src/messaging/emailTemplates.ts`, `ResendEmailProvider`) now go
  out as text plus a simple HTML part (`emailHtml.ts`) in which a bare `https://` address becomes an `<a>`. The
  confirmation e-mail already carries the personal link `{link}` (the `/m/{token}` management page, where the client can
  reschedule or cancel). In a Junk folder Outlook disables links, which is part of why they looked like text.
- The messages the professional sends from the app (WhatsApp through `wa.me`, `MessageService`, `QuickReplyRenderer`,
  `BuiltInQuickReply`, reminders ready, win-back, birthday, waitlist offers, share-link texts) fill `{link}` with the
  DISPLAY form of her booking page (`bellohub.app/maria`, no `https://`), see `BookingLink.display` and the tests that
  expect `.../maria`. A link without a scheme is not reliably clickable in WhatsApp, SMS or iMessage.
- Those messages carry the professional's generic booking page, not the client's own manage link. The app cannot build
  `/m/{token}`: the server keeps only token hashes (`sendReminders` mints one more valid link per reminder, at most
  five valid per booking).
- There is no store address in the profile contract (`contracts/profile.ts`). The only place name is the profile's
  `city`, used for the ICS `LOCATION`.

## What to build

1. **Every link in every message to a client is a full `https://` URL.** Audit all builders in the app (quick replies and
   their built-ins in 14 localizations, `{link}` rendering, message previews, reminders ready, win-back, birthday,
   waitlist offer, "Suggest another time", share-link sheet, cancel / no-show / running-late messages) and on the server
   (e-mail templates, WhatsApp template parameters in `whatsAppTemplates.ts`, ICS `URL`, push). A shared pure type owns
   the rule ("a client-facing link is `url.absoluteString`"), with tests; the display form stays for places where she
   reads the address herself. Placement: a link on its own line, nothing glued after it (no trailing punctuation), so
   the chat app detects all of it.
2. **The exact link to change or cancel.** For an appointment that came from the booking page, the message to that
   client must carry her personal manage link `https://bellohub.app/m/<token>` (the page already offers reschedule and
   cancel). Add an owner-only callable (for example `mintManageLink`, input: the booking id; output: the URL) that reuses
   the existing token machinery (hashed at rest, at most five valid per booking, rate limited, idempotent for a short
   window, audit-free of personal data, emulator tests, `API.md`, schemas); the app calls it when she opens the message
   sheet or taps send, shows "Preparing the link" while it waits, and falls back to her booking page link when she is
   offline, the appointment is manual (no server booking), or the call fails (say which link was used in a quiet line).
   The reminders the server sends itself already mint their own link. Make sure the page the link opens says clearly
   "Change or cancel" first (check `/m/{token}`), and that the link works from WhatsApp's and Instagram's in-app
   browsers.
3. **The store's location in the confirmation.** Add an optional address to the professional's settings:
   fields for street and number, postal code, city, country (default from the business region), an optional "how to find
   us" note (floor, bell, landmark) and a generated map link (Apple Maps and Google Maps URLs built from the address, with
   no SDK and no geocoding call). Privacy: many professionals work from home, so she chooses where it shows: (a) only to
   clients with a confirmed booking (confirmation e-mail, confirmation page, manage page, ICS `LOCATION`, WhatsApp
   `{address}`), which is the DEFAULT, or (b) also on the public booking page. Nothing public until she fills it and
   chooses. Publish it with the profile through the existing publishing service (contracts, `PublishPayloads`, server
   schemas and rules, `API.md`), include it in: confirmation, request-received, approved and rescheduled e-mails (all 14
   localizations), the web confirmation and manage pages, the ICS file (`LOCATION` plus the map link in `DESCRIPTION`),
   and a new quick-reply word `{address}` used by the built-in "Confirm appointment" and "Reschedule" messages. The
   settings screen lives in Booking settings (a "Where you work" section with a live preview of what the client sees),
   follows DESIGN.md, strings in 14 localizations, tests, VoiceOver, AX5, light and dark.
4. **E-mail polish that helps the clickable links and the junk problem:** keep the HTML part simple and branded with the
   app's tokens (creme background, graphite text, orange link), put the "Change or cancel" link as a clear link on its
   own line plus a button-looking link, add the address block, and add an optional `Reply-To` parameter
   (`EMAIL_REPLY_TO`, empty by default; when set, it is sent). No images, no tracking.

## Rules

- No deploy by the agent for the app; the coordinator deploys functions and hosting after the checks. Never touch `main`.
- Existing data keeps working: every new field is optional. Do not break old links (`/{slug}` and `/m/{token}`).
- Strings through new batches in `Config/Locale/strings/` plus `python3 scripts/merge-strings.py --prune`, in the S11
  per-language style; `scripts/check-strings.sh --final` must pass.
- Gates: `scripts/test.sh fast`, `scripts/check-warnings.sh`, `scripts/test-firebase.sh`, `scripts/test-web.sh full`
  (WebKit has flaked under load; re-run before concluding), `scripts/e2e-local.sh`, relevant UI tests, audits at AX5 for
  the new settings section in en and pt-BR.
- Report what needs a real iPhone (WhatsApp opening with the exact link, the link opening from WhatsApp and Instagram,
  Apple Maps) and what was verified only with mocks.
