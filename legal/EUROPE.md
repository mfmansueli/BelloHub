# The European legal set: a common GDPR core plus national annexes

Owner plan (docs/16-MARKETS.md section 2, docs/03-BUILD-PLAN.md S11): Brazil and Europe open first, and Europe gets one
legal set built as **a common GDPR core plus national annexes**, so a lawyer reviews the core once and each country only
for its annex. From version `2026-10-2` the terms (`terms-dpa`) and the privacy policy (`privacy-policy`) of the six
European localizations follow this shape, and `scripts/check-legal-status.sh` checks it (header `structure:
gdpr-core + annex XX`, a Part A and a Part B heading).

| Localization | Annex | Countries | Authority named | National points in the annex |
|---|---|---|---|---|
| `pt-PT` | PT | Portugal | CNPD | Lei 58/2019; age of digital consent 13; consumer ADR and Livro de Reclamações |
| `es` | ES | Spain | AEPD | LOPDGDD; age 14; digital rights of staff; consumer arbitration |
| `it` | IT | Italy | Garante | Codice Privacy (D.Lgs. 196/2003 as amended); age 14; Codice del consumo |
| `fr` | FR | France | CNIL | Loi Informatique et Libertés; post-mortem directives; HDS question; age 15; consumer mediator |
| `de` | DE (+ AT, CH notes) | Germany, Austria, Switzerland | Land authority; DSB (AT); EDÖB (CH) | BDSG; Impressum (DDG); consumer dispute statement; DSG (AT); revDSG (CH) |
| `en-GB` | UK (+ IE, AU, NZ, ZA notes) | United Kingdom, Ireland, Australia, New Zealand, South Africa | ICO; DPC (IE); OAIC; OPC (NZ); Information Regulator (ZA) | UK GDPR and DPA 2018; IDTA; ICO fee; Consumer Rights Act; Australian Consumer Law |

## Part A, the core (same section numbers and meaning in every language)

Privacy policy: A1 who we are (controller for her account, processor for her clients' data); A2 what we collect (Sign in
with Apple or phone, the client's email for the verification code, sealed envelopes, the registration counter);
A3 purposes and legal bases (Art. 6(1)(b), (c), (f); Art. 9 through the professional; no consent text, no signature);
A4 where clinical information lives; A5 sub-processors; A6 transfers; A7 retention (7 days, 30 days, 30 days for account
deletion); A8 security and its honest limit; A9 AI on the device; A10 rights (one month); A11 minors; A12 changes.

Terms: A1 the service (no medical advice, no payments); A2 account and recovery key; A3 price and the 10 free
registrations (D42, no trial); A4 her duties (no consent text from us, D55); A5 health information; A6 the Art. 28
agreement (eleven points); A7 IP; A8 availability; A9 ending; A10 liability; A11 changes.

## What changed from 2026-10 (the facts of D44 to D55)
Sign in with Apple as the main sign-in (phone as alternative); the client's email is used to verify a booking (D46) and
is no longer optional online; check-ins and data requests travel sealed like the health form; Bello Hub writes no
consent text and asks for no signature, the app records only that a consent exists (D55); the free allowance is 10
registrations with no trial (D42); the registration counter is disclosed.

Brazil (`pt-BR`, LGPD) is written on its own, not as an annex: the LGPD is not the GDPR, and the ANPD, the
*encarregado* and the 15-day answer of art. 19 are named in the text. Every other region set got the same facts as
targeted edits in its `2026-10-2` version.
