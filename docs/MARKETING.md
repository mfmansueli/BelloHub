# Marketing copy: approved phrases and how to use them

Approved by the owner on 2026-10-11 (task `docs/tasks/routine-simplification.md`, "Frase aprovada para marketing
futuro"). Store listing drafts live in `docs/store/`; markets and channels in `docs/16-MARKETS.md`. Copy rules for any
claim about privacy: `docs/06-PRIVACY-SECURITY.md` section 12.

## The phrases (owner's text, pt-BR, verbatim)

| Use | Phrase |
|---|---|
| Main | **"Você não está mais sozinha. Bello Hub, com você em cada etapa."** |
| Contextual (when the subject is the visit itself) | **"Você não está mais sozinha. Bello Hub está com você em cada atendimento."** |

## Where to use them

- **App Store listing**: the opening line of the description (added to every `docs/store/<localization>.md` draft;
  the 170-character promotional texts are already full, see below).
- **Landing page and social profiles**: headline or sub-headline next to what the app does (agenda, booking link,
  client record).
- **E-mails to professionals** (welcome, newsletters, release notes): as an opening or a sign-off. The contextual
  variant fits messages about the visit flow (records, photos, follow-ups).
- **Presentations, flyers, trade fairs.**

## Where not to use them

- **Never as a new onboarding step** or an extra screen in the app (the owner's rule: no step is added to onboarding
  for this). If it ever appears in the app, it is in an existing place (for example the About screen), never in a flow.
- **Never in messages to clients** (WhatsApp, booking e-mails, the booking page): clients are not the audience, and
  those texts carry booking facts only (`docs/06` section 8).
- **Never next to a promise the app does not keep.** "With you in every step" is about support and continuity, not a
  feature list: do not pair it with features that are not in the build (voice notes are not in v1, automated WhatsApp
  is post-v1, there is no human support line, no payments). Store copy rule: only features in this build
  (`docs/store/README.md`).
- **Not as a legal or medical claim** (it does not mean supervision, insurance or clinical advice).

## Adaptations (all `needs_review`, D41: no native reader yet)

The Portuguese phrase speaks to a woman ("sozinha"), which is the owner's choice for the main audience. Where a
language marks gender, the feminine is kept to match; a neutral line is given for copy that must also speak to men
(barbers, tattoo artists). English, German, Turkish and Indonesian are neutral already.

| Localization | Main | Contextual | Neutral alternative | Status |
|---|---|---|---|---|
| pt-BR | Você não está mais sozinha. Bello Hub, com você em cada etapa. | Você não está mais sozinha. Bello Hub está com você em cada atendimento. | Bello Hub, com você em cada etapa. | approved (owner) |
| pt-PT | Já não está sozinha. Bello Hub, consigo em cada etapa. | Já não está sozinha. Bello Hub está consigo em cada marcação. | Bello Hub, consigo em cada etapa. | needs_review |
| en, en-GB | You're not alone anymore. Bello Hub, with you every step of the way. | You're not alone anymore. Bello Hub is with you at every appointment. | (already neutral) | needs_review |
| es, es-MX, es-419 | Ya no estás sola. Bello Hub, contigo en cada paso. | Ya no estás sola. Bello Hub está contigo en cada cita. | Bello Hub, contigo en cada paso. | needs_review |
| it | Non sei più sola. Bello Hub, con te in ogni fase. | Non sei più sola. Bello Hub è con te a ogni appuntamento. | Bello Hub, con te in ogni fase. | needs_review |
| fr | Vous n'êtes plus seule. Bello Hub, à vos côtés à chaque étape. | Vous n'êtes plus seule. Bello Hub est à vos côtés à chaque rendez-vous. | Bello Hub, à vos côtés à chaque étape. | needs_review |
| de | Du bist nicht mehr allein. Bello Hub, an deiner Seite bei jedem Schritt. | Du bist nicht mehr allein. Bello Hub ist bei jedem Termin an deiner Seite. | (already neutral) | needs_review |
| tr | Artık yalnız değilsiniz. Bello Hub, her adımda yanınızda. | Artık yalnız değilsiniz. Bello Hub her randevuda yanınızda. | (already neutral) | needs_review |
| id | Kamu tidak sendirian lagi. Bello Hub, menemanimu di setiap langkah. | Kamu tidak sendirian lagi. Bello Hub menemanimu di setiap janji temu. | (already neutral) | needs_review |
| hi | अब आप अकेली नहीं हैं। Bello Hub, हर क़दम पर आपके साथ। | अब आप अकेली नहीं हैं। Bello Hub हर अपॉइंटमेंट में आपके साथ है। | Bello Hub, हर क़दम पर आपके साथ। | needs_review |
| ar | لستِ وحدكِ بعد الآن. Bello Hub معكِ في كل خطوة. | لستِ وحدكِ بعد الآن. Bello Hub معكِ في كل موعد. | Bello Hub معك في كل خطوة. | needs_review |

Notes for a reviewer: the register follows the app's (de *du*, id *kamu*, tr *siz*, fr *vous*, hi *आप*, pt-PT
without *você*); the visit word follows the glossary (`docs/strings/glossary.csv`: pt-PT *marcação*, es *cita*, de
*Termin*, tr *randevu*, id *janji temu*); the French store drafts use *vous*, so the feminine *seule* is the only
gendered word and the neutral line drops it.

## In the store drafts

The main phrase (in the localization's version above) is the first line of the description in every
`docs/store/<localization>.md`, and each description's length was recounted (all far under 4000). It was **not** put
in the promotional text (≤ 170 characters): those are 92 to 158 characters already and say what the app does; adding
the phrase would pass 170 in every language but Arabic, and the slot is better kept the same everywhere. If a
promotional text is rewritten later, the phrase alone fits (72 characters at most, in German).
