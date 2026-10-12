# Motion 1 to 5 (2026-10-12)

Five motion items approved by the owner, built on `build/v1` from `2f96950`, one agent, nothing server-side. Spec:
`docs/09-MOTION.md` section 8 (exact values). Design: `DESIGN.md` "Motion".

## What changed

The kit (`BelloHub/DesignSystem/Motion/`):
- `MotionChange` (pure): the animation for a kind of change under a `MotionPolicy`, the number style, the row diff
  (`rowChange`, `rowsAnimation`, `rowStyle`, `postsLayoutChange`). Every rule is unit tested.
- `MotionNumberModifier` (`motionNumber`), `MotionRowsModifier` (`motionRows`, `motionRow`), `MotionSettleModifier`
  (`motionSettle`), `DaySlide` (+ `motionDaySlide`), `ConfirmationCue` (+ `ConfirmationSealModifier`), `CaptureFlash`.
- Components: `InlineCheck`, `CheckShape` (extracted from `SuccessSeal`). Tokens: `Duration.change` 0.3,
  `reducedFade` 0.2, `flash` 0.12, `slideOffset` 24, `flashOpacity` 0.2.
- DEBUG launch switch `-uiAnimate` (`LaunchOptions.keepsAnimations`): keeps animations on in a UI test. Every other
  launch (`-uiTesting`, `-uiReduceMotion`) stays instant, so the existing suites are not slower or flakier.

1. Numbers: see 09 section 8.1 for the screens. The first text a view shows is not animated; unchanged values do not move.
2. Rows: Home (`HomeBlockIDs`), Alerts (`AlertBlockIDs`), follow-up queue (context = filter), waitlist, calendar day and
   week, Clients list. Only 1 to 12 changed identities animate; load, other context, bulk never do.
3. Confirmations: saved step (`SuccessSeal` 56), brief seal on photo saved / marked as sent / offer sent / request
   accepted, `InlineCheck` in the message sheet and the New client Save button, haptics on Edit client and when the closing
   finishes. Checked: before this work the saved step had no seal and no haptic.
4. Camera: flash (checked: it was not there), reference fade, before/after settle. The before/after handle was already the
   system `Slider` (1:1, speaks its percent to VoiceOver), so it is kept and only gained the settle.
5. Calendar: slide by direction of travel (`CalendarViewModel.travel` and `contentKey`, presentation state only), chip
   `matchedGeometryEffect`, now line and moved visits glide.

## Decisions to know

- **There is no drag-to-move on the calendar** (moving is the Reschedule sheet). Adding one would be new behaviour
  (conflicts, confirmation), which the brief excludes, so item 5 "follows the finger" is not built; the settle
  (`motionSettle`) is what a future drag must call. A rescheduled visit glides to its new slot.
- The soft overshoot is not used by any of the new motion (docs/09 allows it only for the seal circle and the switch).
- Reduce Motion: no flash (a flash is a sudden change; the haptic stays), no slide, a block that changes place just is
  there, numbers and rows crossfade at most 0.2 s. The gap closing next to a removed row shares that 0.2 s fade.
- The day slide only moves the arriving content and fades the old one (a removal reads the transition it had before the
  change, so a direction on it would be stale). Old and new share one place in a `ZStack` while they cross.
- Clients is a native `List`: it keeps its own row animation, our curve is applied through `.animation(value:)` and
  only for 1 to 12 changed rows.
- Treatment flow: nothing new moves in the clinical steps except the seal (saved, photo) and the flash.
- No new visible string.

## Measured

- `scripts/test.sh fast`: 2424 tests in 355 suites passed (was 2385+ before).
- `scripts/check-warnings.sh`: zero warnings (simulator, device, Release, test targets).
- Performance, `PerformanceUITests` on the 2,000-client list, iPhone 17 simulator (`-uiTesting`, so animations off):

  | | before (`2f96950`) | after |
  |---|---|---|
  | scroll deceleration (5 runs) | 2.435 s | 2.436 s |
  | scroll dragging | 0.145 s | 0.137 s |
  | search over 2,000 (signpost) | 12 ms (s8-leftovers notes) | 12 ms |

  No regression. The animated path itself was not profiled (simulator); see below.
- `MotionUITests` (new, 7): day and week with animations on and with Reduce Motion, a request answered leaves its card
  (on and Reduce Motion), a queue row dismissed leaves, the treatment flow saves, flashes and goes on (on and Reduce
  Motion). All green on the first run.

## Needs a real iPhone (iPhone 15 Pro)

The simulator screenshot arrives after the 0.3 s has passed, so the motion was not seen in flight. To check by hand:
1. How the day slide, the chip, the now line and the rows feel at 60 fps (Instruments, Animation Hitches; target no hitch
   over 8 ms). The row transitions inside `ListCard` (`Group(subviews:)`) and the matched chip are the two places to look.
2. Haptics: seal (success), photo flash (medium impact), inline check, marked as sent, closing finished.
3. VoiceOver with row removals: dismiss a queue row, answer an Alerts request, remove a waitlist person; focus must land
   on a row that exists (a `LayoutChanged` is posted when rows leave).
4. The camera flash against the real preview, and with Reduce Motion on (no flash, haptic stays).
5. Low Power Mode and Reduce Motion toggled in Settings (the DEBUG switches only stand in for them).
