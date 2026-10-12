# Record fields and quick answers by niche (2026-10-12)

The owner tested the visit form on an iPhone and asked for it to be specialized per niche: each profession should find
the topics it really tracks, with ready-made tags to answer in one tap, plus the free text and "+ Add". Reactions matter
much more for skin care, lashes, permanent makeup and hair color than for nails or barbers.

## What changed

- `Resources/Professions/professions-<code>.json`: every field of every profession carries `tags` (its quick answers),
  and every profession carries `reactionTags` and `aftercareTags` for the fields every visit has. Field lists were
  revised with the research below (new: esthetician health check and phototype, hair natural level, patch and strand
  test, lash natural lashes and lift settings, nail service, makeup skin type, lashes and setting, PMU procedure,
  contraindications and skin response, barber neckline and skin, massage findings, pain and post-op details). Fields
  that duplicated the shared reaction or aftercare fields were dropped from the catalog (a dropped field disappears
  from the form because the catalog no longer names it; old records keep their entries and names).
- A field already in her template keeps its key and her on/off choice. Fields the catalog added reach her form through
  `RecordTemplate.completed`, in their catalog place.
- Written fields show their quick answers as chips under the note: a tap writes the answer on its own line, a second tap
  takes it out, and anything can still be typed. "+ Add" writes a new answer; "Save to reuse" keeps it in the field's
  answers in her template (seeded with the profession's, so none is lost), or for techniques, reactions and aftercare in
  her saved options (`OptionContext.technique`, `.reaction`, `.aftercare`; editable in Personalization).
- Fields with quick answers never fold under "More fields": they are one tap each.
- `scripts/check-professions.sh` checks that every language has the same number of answers as English, each filled,
  at most 32 characters, and none repeated.

## Research summary

- Esthetician: contraindications (isotretinoin, retinoids, pregnancy, recent sun, cold sores) and the Fitzpatrick
  phototype (risk of dark marks after inflammation, needle depth) are critical; settings of the last peel or needling
  session are the main pain point.
- Hair: the lost or vague formula is the top pain point; chemical history (box dye, henna, keratin) and the 48 h allergy
  alert test (PPD) belong on the card.
- Lash: cyanoacrylate allergy builds up over time; retention depends on humidity, adhesive age and oily lids; the exact
  map rebuilds a set at refill.
- Nail: lifting location tells the cause; (meth)acrylate/HEMA allergy is rising in the UK and EU, so the product line
  and HEMA-free matter; onycholysis and fungus mean refer.
- Makeup: event context, skin type and prep, exact foundation and shade with oxidation, lashes and glue, longevity.
- Tattoo and PMU: contraindications (pregnancy, isotretinoin, blood thinners, keloids), pigment and cartridge lot for
  traceability, the healing timeline and retention at the 6–8 week touch-up.
- Barber: guard number per zone, fade type and height, neckline and beard; razor bumps and ingrown hairs.
- Massage: contraindications (especially for lymphatic drainage), pressure per area, findings, nut-oil allergy, and
  post-surgery drainage details (very common in Brazil).

## Sources (trade, training and public-health pages; no single official standard exists for any niche)

- open-exam-prep.com: client consultation record keeping; colour consultation and testing; WA master esthetician
  perioperative documentation.
- typeform.com hair-color consent template (48 h patch test).
- BfR, "The conundrum of hair dye contact allergy" (bfr.bund.de).
- cosmeticsdesign-europe.com: EC stronger warning on hair dye products.
- NHBF (UK) consultation and allergy alert record cards.
- alteg.io client card templates (cosmetology, lashes, nails).
- salonserve.com lash chart; lashjungle.com and stacylash.com on adhesive allergy vs irritation; lashaffair.com and
  lovelyus.com on retention and humidity; purespadirect.com on lash lift shields and timings.
- boaconta.com.br: POP for lash designers and for micropigmentation biosafety (Brazil health inspection expectations).
- vitat.com.br on PMU aftercare; pabau.com microblading aftercare and microneedling depth chart.
- Toronto Public Health BodySafe micropigmentation IPAC (cartridge lot on the client record).
- skinhealthinfo.org.uk (British Association of Dermatologists) on the acrylate nail allergy; cosmeticsbusiness.com on
  the UK government investigation into gel polish allergy; katiebarnesacademy.com on nail service breakdown;
  folhavitoria.com.br on fiberglass vs gel.
- mangoapps.com foundation colour match record; weddingsonline.ie on bridal trials.
- sanovadermatology.com on razor bumps; zandahealth.com and pro.massagebook.com on massage SOAP notes;
  rededorsaoluiz.com.br on lymphatic drainage in pregnancy; starbritecolors.com on tattoo blowouts.

The tags are a synthesis of these sources. The translations were written per market vocabulary and are `needs_review`
like every catalog until a native professional reads them (D41).
