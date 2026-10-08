# 12 · AI and voice (on-device)

Decision D23: transcription and structuring run **on the iPhone**. Nothing a professional dictates, no transcript and no structured text leaves the device. The AI assists; the professional reviews and decides (D9).

Screens: `5.1` Tx-1-Register, `5.2` Tx-2-Listening, `5.3` Tx-3-Organizing, `5.4` Tx-4-Review, `5.5` Tx-Form (manual path), `5.6` Tx-5-Saved, `7.5` AISettings.

**Verify every API name and availability against the installed SDK before using it** (Xcode 26 or newer; the owner builds with Xcode 27; deployment target iOS 26, D39). The names below are the intended frameworks; if an API differs, adapt and record it in `PROGRESS.md`.

## 1. Pipeline

```
 mic ──▶ AppleSpeechTranscriber (SpeechAnalyzer / SpeechTranscriber, on-device) ──▶ transcript chunks
        └─▶ live text in Tx-2-Listening (volatile + finalized results)
 transcript ──▶ RecordStructuringService (Foundation Models, on-device) ──▶ StructuredRecord (typed fields)
        └─▶ Tx-3-Organizing (progress) ──▶ Tx-4-Review (editable draft, source quotes) ──▶ save (vault)
 fallback: Tx-Form (manual fields, system dictation allowed)
```

## 2. Transcription

- Framework: `Speech` (iOS 26 **SpeechAnalyzer** with `SpeechTranscriber`, on-device models). Request microphone and speech permissions only when she taps record, with the localized pre-explanation from `Permissions`.
- **Locale support check**: before recording, `supports(locale:)` for the chosen "Voice language" (default: business locale). If the on-device model is not installed, ask the system to download it (the framework exposes asset installation) and show progress; if unsupported, **do not** fall back to server recognition (`requiresOnDeviceRecognition = true` semantics): offer system dictation in the manual form or typing.
- Streaming: show results as they arrive; keep the audio in memory/temp storage only until the transcript is final; **delete recordings after organizing** (default on, setting in `AISettings`); never upload.
- Interruptions (phone call, route change), background (stop cleanly and keep the transcript), 3-minute soft limit with a gentle prompt, 10-minute hard limit; handle low disk. Waveform from input level at ≤ 30 fps, static meter under Reduce Motion.
- Accuracy aids: pass the professional's terms (product names, services, her client's name) as contextual strings/custom vocabulary if the API offers it; show low-confidence words subtly (underline) in review.

## 3. Structuring

- Framework: **Foundation Models** (on-device language model). Check `SystemLanguageModel.default.availability`: handle `available`, `unavailable(reason)` (device not eligible, Apple Intelligence off, model not ready) and the locale support of the model for the transcript language; if not available, show the manual path (`Tx-Form`) with a one-line explanation (no jargon) and keep the transcript as notes she can edit.
- **Context window is small (≈ 4096 tokens including instructions and output).** Strategy: (1) keep the prompt short; (2) if the transcript is long, split by sentences into chunks (~1,200 tokens), extract per chunk with the same schema, then merge deterministically in code (concatenate lists, keep the last scalar value mentioned, de-duplicate products); (3) never ask the model to rewrite the whole record in one pass.
- **Guided generation** with `@Generable` types: the structured schema is built **from the profession's record template** (`RecordFieldTemplate`): fields such as `products: [String]`, `technique: String`, `skinReaction: enum`, `result: enum(great|good|neutral|reaction)`, `aftercare: String`, `nextVisitWeeks: Int?`, `notes: String`. Include the professional's term for each field in the prompt. Keep generation options conservative (low temperature / greedy) so output is stable.
- **Hard rules in the prompt and in code** (code enforces them even if the model ignores them):
  1. Use only information present in the transcript. If a field was not mentioned, leave it empty.
  2. Never infer, add or normalize a product, ingredient, technique, allergy, reaction or result not said.
  3. No diagnosis, no medical advice, no judgments.
  4. Preserve numbers, names and brand spellings as dictated.
  5. Output in the transcript's language.
- **Grounding check** (pure code, tested): for every product/technique/result the model returns, verify a fuzzy match exists in the transcript; anything ungrounded is dropped and counted ("2 items removed because they were not in your recording" shown in review).
- Safety: Foundation Models' guardrails may refuse or return partial content; treat errors (`guardrailViolation`, context overflow, unsupported language) as a signal to fall back to manual with the transcript preserved.
- Prompt injection: the transcript is data, not instructions; wrap it in clear delimiters and never let model output trigger actions (it only fills fields).
- Offline and private by construction. No network call in this module (a test asserts the module does not import networking types and that `URLSession` is not referenced).

## 4. Review (always)

`Tx-4-Review` shows each field with the organized value, the **source phrase** from the transcript on tap, and an edit control; the professional can add fields manually; **nothing saves without her explicit "Save record"**. The record stores `source = voice`, `aiAssisted = true` and the edit trail starts at creation (24-hour lock rule, `RecordLockPolicy`). Review is always required (the prototype setting "Review before saving: always check the draft first" is on and **cannot be turned off in v1**; show the toggle as on and disabled with an explanation, list under "Design additions").

## 5. Manual path (equal citizen)

`Tx-Form` is a fast form built from the same template. Dictation into any text field uses the system keyboard dictation. A device without Apple Intelligence, an unsupported language, or a user who prefers typing gets the same flow, same save, same review step minus the AI banner. Tests prove the whole save path works with `-uiNoAI`.

## 6. `AISettings` (7.5)

- "Where it runs": always "On this iPhone". Status line: Ready / Not available on this iPhone / Language not supported yet / Downloading.
- "Cloud help for older iPhones": **disabled, "Not available yet"** (D23).
- Settings: review before saving (on, locked), delete recordings after organizing (on by default), voice language, record fields (opens `RecordTemplate`).
- "What it never does" copy stays; it must be true: tests cover the grounding check and the review gate.

## 7. Tests and measurements

- `StructuringService` is a protocol; tests use a fake that returns canned structured output; **grounding check**, **chunk-and-merge**, and **fallback decisions** are pure and table-tested (including empty transcript, very long transcript, unsupported locale, model unavailable, guardrail error).
- Fixtures: ten realistic transcripts per language (the ten languages; derived localizations reuse their parent's; written by you, fictional, no real people) exercising products, numbers, negations ("no usé ácido", "não apliquei peeling"), self-corrections ("no, perdón, dos minutos") and brand names.
- Real-device checks (human, H3): transcription accuracy per locale, time to first text, model latency per chunk, battery. Record numbers in `PROGRESS.md`.
- Never log transcripts or model output; telemetry events carry only durations and booleans.

## 8. Language support differs by language and by iOS version: check at runtime, never assume

Bello Hub is localized in ten languages, but Apple's speech and language models support their own list, which changes with iOS releases and with downloaded assets. Therefore:

- **Never hard-code** which languages work. Ask the system each time: `SpeechTranscriber.supportedLocales` / `installedLocales` (and the asset installation API) for transcription, `SystemLanguageModel.default.supportedLanguages` and `.availability` for structuring (verify the exact names against the installed SDK).
- Two separate answers: *can it transcribe this language?* and *can the model structure this language?* Combine them into one `VoiceCapability` per voice language (pure type, table-tested): `full` (transcribe + structure), `transcribeOnly` (transcript becomes editable notes, structure by hand), `none` (manual form and keyboard dictation if the system offers it).
- The **voice language** is chosen in `AISettings` and defaults to the business localization's language; she can pick another (a Brazilian professional may dictate in English for a foreign client). Derived localizations use their parent's language code for the check (`es-419` → Spanish).
- Status line wording per capability: Ready / Notes only in this language / Not available in this language yet / Downloading; each localized. Arabic and Hindi, Turkish and Indonesian may be `transcribeOnly` or `none` on a given iOS version; the app must be fully usable in both cases (section 5).
- Record the matrix you observe on the simulator and, later, on real devices (H3) in `docs/spikes/VOICE-LANGUAGE-MATRIX.md` (iOS version, device, language, capability). Do not promise a language in store copy or in the app unless the matrix shows it works.
