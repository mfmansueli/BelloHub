# Breach plan (one page)

What the owners do when they suspect that personal data handled by Bello Hub was exposed, lost or changed without
permission. Engineering guidance from `docs/06-PRIVACY-SECURITY.md` §9, not legal advice (`LEGAL-REVIEW`, H11).
Roles: the professional is the **controller** of her clients' data; Bello Hub is the **processor** of the operational
data on its servers. So we tell **her** without delay, and she decides what to tell her clients and her authority; we
help her with facts.

## 1. What can be affected (and what cannot)

| Where | What is there | If exposed |
|---|---|---|
| Firebase (Firestore, Storage, Functions logs) | Operational data (class O): client name, phone, optional email, service, time, status, policies, availability, push tokens, account ids, registration counters; sealed envelopes | Names and phones and booking facts of clients; **no health data in readable form**: envelopes are HPKE-sealed to the professional's key and the server never had the key |
| Public pages (`publicProfiles`) | What she chose to publish (class P) | Already public |
| Her iPhone and her iCloud | Records, photos, health forms, notes (class S), encrypted by the app (D26) | Only a lost or unlocked phone, or her Apple Account taken over **and** her recovery words: the server side cannot leak it |
| Email provider (Resend) | Booking emails: what, when, link, rules | Booking facts and client email addresses |
| App Store / Apple | Subscription status | Apple's own process |

## 2. First hour (owners)

1. **Write down** what was seen, when, by whom, and keep every log (Cloud Logging, Firebase console audit, GitHub).
   Logs carry ids and sizes only, no personal data (`check-privacy.sh` rule 6), so they can be shared with a lawyer.
2. **Contain**: rotate the leaked secret (Secret Manager: `PHONE_HASH_PEPPER` is **never** rotated, it would break every
   phone hash; `EMAIL_API_KEY`, `APPLE_SIGNIN_PRIVATE_KEY` can be), revoke a leaked service-account key, turn
   `ENFORCE_APP_CHECK` on if the abuse comes through the functions (only when the web exemption is in place, H5),
   tighten a Firestore rule and redeploy only the rules (`firebase deploy --only firestore:rules`).
3. **Revoke client links** when manage or portal tokens may have leaked: the tokens are stored hashed; deleting the
   hashes from the bookings and `portal` documents ends every link (clients use "Find my appointment" with a code).

## 3. First 72 hours (GDPR art. 33 asks the controller within 72 h; LGPD asks within a "reasonable time")

4. **Tell each affected professional** by email: what happened, which of her data and her clients' data, what we did,
   what she can do. Template: facts only, no speculation, no "your data is safe" unless it is proven.
5. She decides whether to notify her clients and her authority (ANPD in Brazil, CNPD in Portugal, AEPD in Spain, the
   lead EU authority otherwise); we give her the facts and timeline in writing.
6. Record the incident (date, data, people, actions) in a private incident log kept by the owners, even when nobody had
   to be notified.

## 4. What the app can do

- **Rotate the inbox key** if the key on the page may have been swapped or her private key exposed: the function
  `updateInboxKey(compromised: true)` makes a new generation current; old envelopes still open on her phone, new forms
  are sealed to the new key. v1 has the call and the rotation model (`KeyRotationPlan`) but **no button**: a rotation
  today needs a build that triggers it. The app also refuses to publish while the page serves a key it did not derive
  (`PublishFailure.keyMismatch`, docs/06 §3.2), and Privacy shows the form key she can compare with the page.
- **Delete a client's server data** ("Delete data" in the client's edit screen) or **her whole account** (More >
  Account > Delete account): both reach the server through the functions and are idempotent.
- **Sign out on every device** by deleting the Firebase Auth user's refresh tokens (console), then she signs in again.
- A lost iPhone: Find My and erase; her records stay encrypted in iCloud and come back with her recovery words.

## 5. Afterwards

7. Write a short post-mortem in `docs/agent-notes/` (no personal data): cause, timeline, fix, the test that now covers it.
8. Update `docs/06-PRIVACY-SECURITY.md` and the privacy policy if the incident showed a gap.
