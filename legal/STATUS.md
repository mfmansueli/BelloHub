# Legal documents status

Every document is a **draft written by Claude Code** (owner decision D40, 2026-10-08): the owner opens markets without
waiting for a lawyer and will send these texts to a lawyer if the product generates interest. Nothing here claims
legal compliance. The professional-facing app does not show the word "draft"; this file is where the status lives.

Status values: `draft` (written, not reviewed by a lawyer) or `reviewed` (a lawyer returned final text; reviewer and
date recorded). `scripts/check-legal-status.sh` prints this table from the files.

The document set per region and the languages are in `docs/07-LOCALIZATION.md` section 8 and `docs/16-MARKETS.md`.
The legal pass (plan item L in `docs/PROGRESS.md`) wrote the 98 drafts below (7 documents x 14 localizations, version
`2026-10`). How the files are organised, the fill-in fields and the facts every text may state are in
[README.md](README.md). `scripts/check-legal-status.sh` fails the build if a file is missing, a header field is absent,
a placeholder is unknown or a text makes a forbidden claim ("GDPR compliant", "unhackable" and similar).

## Open points for the lawyer (if the product gets traction)

These are things the drafts cannot settle without knowing the operator or without local advice. They are listed so the
reviewer starts from the right places and nobody mistakes a draft for a finished text.

1. **Operator identity and law.** `{{OPERATOR_NAME}}`, `{{OPERATOR_ADDRESS}}` and `{{OPERATOR_EMAIL}}` are not filled in
   (human task H17). The governing-law clause points to "the place where we are established". If the operator is outside
   the EU/UK, an EU/UK representative (GDPR art. 27) and a data protection officer or contact may be required.
2. **Roles.** The drafts treat the professional as controller and Bello Hub as processor for client data, and Bello Hub as
   controller of the professional's account. Confirm this split, especially for the booking pages shown to clients.
3. **Minors.** The product says clients are 18 or older, with a guardian consenting for a minor. Ages of digital and
   health consent differ by country (13 to 18). Confirm the cut-off and the guardian flow per market.
4. **Time limits we state.** 30 days for access/deletion answers (Brazil's LGPD art. 19 says 15 days for the full
   declaration; Mexico's LFPDPPP says 20 business days; both are written into those drafts), 72 hours for breach notice
   from processor to controller, 7 days booking retention, 30 days sealed health-form retention. Confirm against local rules.
5. **Health and sensitive data.** The product design keeps clinical data off the servers, so most transfer and
   localisation rules should not bite, but check: Saudi Arabia and the UAE (health-data localisation rules), Turkey
   (explicit consent for cross-border transfer, VERBIS registration for the professional), India (DPDP transfer
   restrictions), Indonesia (transfer conditions), and US state health-data laws (Washington, Nevada, Connecticut).
6. **United States.** The `en` terms say Bello Hub is not designed to be a HIPAA business associate. Confirm, and decide
   whether to publish a "Notice at collection" and a "Do not sell or share" statement as separate pages.
7. **Consumer rules for the subscription.** Apple handles billing. Check consumer-law disclosures per market (price
   including taxes, renewal and cancellation wording, the limit explainer "Your first 10 client registrations are free").
8. **Website obligations.** Some countries require an imprint (Germany, Austria: Impressum) or a cookie notice. The
   booking pages store no cookies today; check again if that changes.
9. **Translations.** All 14 localizations were written by Claude Code, none reviewed by a native reader or a lawyer
   (owner decisions D40 and D41). Legal terms in Hindi, Arabic, Turkish and Indonesian especially need a local pass.
10. **Apple requirements.** The App Store needs a privacy policy URL (`{{WEB_BASE_URL}}/privacy`), in-app account
    deletion (planned in S3), and accurate App Privacy answers (`docs/16-MARKETS.md`).
11. **Gendered forms.** The drafts address the professional in the feminine where the noun allows it ("la profesional",
    "a profissional") and, in es, it, fr, de and pt, often the client too ("clienta", "cliente", "Kundin"). The app's own
    strings follow the glossary instead (neutral: "cliente", "Kundschaft"). A pass should make the legal drafts match the
    glossary, or the owner should decide that the legal texts keep the feminine, as the typical user does.
12. **Turkish.** "uygulama" means both "app" and "treatment"; the drafts use "işlem" for a treatment and keep "uygulama"
    for the app. Check the other languages for the same kind of overlap.

<!-- table:start -->
| Document | Localization | Region set | Version | Status | Framework |
|---|---|---|---|---|---|
| terms-dpa | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| terms-dpa | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| terms-dpa | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| terms-dpa | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| terms-dpa | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| terms-dpa | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| terms-dpa | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| terms-dpa | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| terms-dpa | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| terms-dpa | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| terms-dpa | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| terms-dpa | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| terms-dpa | hi | India | 2026-10 | draft | DPDP Act 2023 |
| terms-dpa | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
| privacy-policy | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| privacy-policy | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| privacy-policy | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| privacy-policy | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| privacy-policy | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| privacy-policy | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| privacy-policy | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| privacy-policy | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| privacy-policy | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| privacy-policy | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| privacy-policy | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| privacy-policy | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| privacy-policy | hi | India | 2026-10 | draft | DPDP Act 2023 |
| privacy-policy | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
| client-notice | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| client-notice | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| client-notice | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| client-notice | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| client-notice | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| client-notice | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| client-notice | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| client-notice | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| client-notice | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| client-notice | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| client-notice | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| client-notice | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| client-notice | hi | India | 2026-10 | draft | DPDP Act 2023 |
| client-notice | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
| consent-health | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| consent-health | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| consent-health | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| consent-health | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| consent-health | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| consent-health | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| consent-health | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| consent-health | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| consent-health | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| consent-health | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| consent-health | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| consent-health | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| consent-health | hi | India | 2026-10 | draft | DPDP Act 2023 |
| consent-health | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
| consent-photo | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| consent-photo | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| consent-photo | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| consent-photo | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| consent-photo | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| consent-photo | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| consent-photo | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| consent-photo | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| consent-photo | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| consent-photo | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| consent-photo | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| consent-photo | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| consent-photo | hi | India | 2026-10 | draft | DPDP Act 2023 |
| consent-photo | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
| consent-guardian | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| consent-guardian | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| consent-guardian | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| consent-guardian | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| consent-guardian | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| consent-guardian | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| consent-guardian | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| consent-guardian | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| consent-guardian | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| consent-guardian | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| consent-guardian | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| consent-guardian | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| consent-guardian | hi | India | 2026-10 | draft | DPDP Act 2023 |
| consent-guardian | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
| data-requests | pt-BR | Brazil | 2026-10 | draft | LGPD (Lei 13.709/2018) |
| data-requests | pt-PT | Portugal | 2026-10 | draft | RGPD + Lei 58/2019 |
| data-requests | es-MX | Mexico | 2026-10 | draft | LFPDPPP |
| data-requests | es-419 | Latin America (AR, CO, CL, PE and others) | 2026-10 | draft | National data protection laws (Ley 25.326 AR, Ley 1581 CO, Ley 21.719 CL, Ley 29.733 PE) |
| data-requests | es | Spain | 2026-10 | draft | RGPD + LOPDGDD |
| data-requests | en | United States | 2026-10 | draft | State privacy laws (CCPA/CPRA, Washington My Health My Data Act and others) |
| data-requests | en-GB | United Kingdom, Ireland, Australia, New Zealand, South Africa | 2026-10 | draft | UK GDPR + DPA 2018; GDPR (IE); Privacy Act 1988 (AU); Privacy Act 2020 (NZ); POPIA (ZA) |
| data-requests | it | Italy | 2026-10 | draft | GDPR + Codice Privacy |
| data-requests | fr | France | 2026-10 | draft | RGPD + Loi Informatique et Libertés |
| data-requests | de | Germany, Austria, Switzerland | 2026-10 | draft | DSGVO + BDSG (DE); DSG (AT); revDSG (CH) |
| data-requests | tr | Turkey | 2026-10 | draft | KVKK (Law 6698) |
| data-requests | id | Indonesia | 2026-10 | draft | PDP Law (Law 27/2022) |
| data-requests | hi | India | 2026-10 | draft | DPDP Act 2023 |
| data-requests | ar | Saudi Arabia, United Arab Emirates | 2026-10 | draft | PDPL (SA); Federal Decree-Law 45/2021 (AE) |
<!-- table:end -->
