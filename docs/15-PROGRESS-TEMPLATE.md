# PROGRESS (copy to `docs/PROGRESS.md` in stage S0 and keep it current)

This file is your memory across context resets. **Read it first in every session. Update it at the end of every stage and whenever something notable happens.** Humans read it to see what happened while they were away.

## Open questions for humans (top = most urgent)
- (none yet)

## Market readiness (keep current; mirrors `legal/STATUS.md`)
| Wave | Market | Language(s) | Strings read by a native | Legal texts reviewed | Open in App Store Connect |
|---|---|---|---|---|---|
| 1 | Brazil | pt-BR | no | no | no |
| 1 | Portugal | pt-PT | no | no | no |
| 1 | Spain | es | no | no | no |
| 1 | Italy | it | no | no | no |
| 1 | France | fr | no | no | no |
| 1 | Germany, Austria, Switzerland | de | no | no | no |
| 1 | United Kingdom, Ireland | en-GB | no | no | no |

(Add one row per market from `docs/16-MARKETS.md`; all `no` until a human changes them.)

## Environment (fill in at S0)
- Xcode: … · iOS runtime: … · SwiftLint: … · Node: … · Firebase tools: … · Java: …
- Pinned dependencies: firebase-ios-sdk …, hpke-js …, preact …, vite …, firebase-tools …

## Current stage
`S0` · started: … · branch: `build/v1`

## Stage log
Append one block per finished stage:

```
### S<n> · <name> · done <date> · tag stage-S<n>
Done: files and features (short)
Decisions/assumptions: ASSUMPTION-<n> …
Deviations from the prototype: … (reason)
Design additions: … (screenshot path)
Measured: contrast …, tests (fast/smoke/full counts), timings …
Open questions: …
Human tasks created: H…
```

## Assumptions
| # | Assumption | Reason | Stage |
|---|---|---|---|

## Proposed changes to CLAUDE.md
(none yet)

## Design additions (for the designer to review)
| Screen | Addition | Why | Screenshot |
|---|---|---|---|
| 7.8 ExportAll | Delivery copy changed to Save to Files / share (no email link) | D18 | |
| 7.5 AISettings | "Cloud help" row disabled, "Not available yet"; review toggle locked on | D23 | |
| 2.4 Notifications / 2.1 Home | "Reminders ready" section | D31 | |
| 8.8 Bk-8-Confirmed | Channel-dependent confirmation copy | D31 | |

## Screen traceability (97 screens; status: todo / in-progress / done / deferred)
Generated from `docs/screens/SCREENS.md`. Add a row per screen with: id, name, stage, status, screenshot match (yes/no), tests, notes.

| Id | Screen | Stage | Status | Notes |
|---|---|---|---|---|

## Spikes and reports
- `docs/spikes/SPIKE-swiftdata-cloudkit.md`: (S2)

## Release checklist
Mirror `13-TESTING-QUALITY.md` §8 and tick as achieved.
