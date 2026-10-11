# 09 · Motion and animation

The prototype has **one** motion layer (decision D20), written once and applied everywhere. In the app it becomes a small kit in `DesignSystem/Motion/` that every screen uses; **no screen invents its own animation.** Motion must feel calm, precise and expensive: it answers a person's action or marks the arrival of a screen, nothing else moves on its own except two small ambient cues.

You cannot play the prototype outside the design tool, so this file is the full specification. Watch the behavior in the live prototype if the owner can show it (the Hub artifact), otherwise build from these numbers.

## 1. Principles

1. **One easing for nearly everything:** ease-out quint, `cubic-bezier(0.22, 1, 0.36, 1)`. Fast start, long soft landing.
2. **One soft overshoot** `cubic-bezier(0.30, 1.25, 0.50, 1)` only for the success circle (and the switch knob, which is the system's own).
3. **Durations 180–560 ms.** Longer only for ambient loops.
4. Motion answers an **action** (press, open, confirm) or the **arrival** of a screen. Ambient motion is limited to the Home "next up" hero glow and the unread dot.
5. **Reduce Motion** removes movement, loops and overshoot (§6). Reduce Transparency removes blur.
6. Never animate layout-heavy lists (use opacity/offset/scale on fixed-size views). 60 fps on an iPhone 12-class device is the bar.

## 2. Tokens (`Motion` enum)

```swift
enum Motion {
    static func ease(_ d: Double = 0.56) -> Animation { .timingCurve(0.22, 1.0, 0.36, 1.0, duration: d) }
    static func soft(_ d: Double = 0.62) -> Animation { .timingCurve(0.30, 1.25, 0.50, 1.0, duration: d) }
    enum Duration { static let press = 0.24, fade = 0.28, rise = 0.56, sheet = 0.46, pop = 0.62, ring = 1.1, draw = 0.5, sheen = 1.5, glow = 14.0, pulse = 2.6 }
    static let riseOffset: CGFloat = 14
    static let stagger = 0.04            // seconds between siblings, first 9 only
    static let lateDelay = 0.36          // every sibling after the 9th
}
```

All helpers read `@Environment(\.accessibilityReduceMotion)` and the DEBUG `-uiTesting` flag (`LaunchOptions`) through one `Motion.isEnabled` check, so UI tests never race animations (the repo's `disablesAnimationsForUITests()` sets a transaction without animation at the root; verify that it also neutralizes `.animation(_, value:)` in children and add an explicit check if it does not).

## 3. The kit and where the prototype uses it

### 3.1 Arrival: staggered rise (`.motionArrival(index:)`, prototype `.noscroll>*`)
Each top-level block of a screen (title, hero, cards, sections) enters with opacity 0→1 and `offsetY` 14→0 over 0.56 s, delayed `0.04 s × index` for the first nine blocks and 0.36 s for the rest. It runs **once per screen presentation** (on first appear of that navigation instance; **not** again when popping back or switching tabs). Apply via a container helper: `StaggeredStack { block block block }` that assigns indices, rather than editing every block by hand. Tab roots animate only the first time the tab is shown in a session.

### 3.2 Press response (`BelloButtonStyle`, prototype `button:active`)
Scale to **0.97** on press (0.985 for full-width rows and list rows), animated `ease(0.24)`, released with the same curve. Also dims 2–3 %. Pair with haptics: `.sensoryFeedback(.impact(weight: .light), trigger:)` on primary actions, `.selection` on chips and segmented changes, `.success` on `SuccessSeal`, `.warning` on destructive confirms. Haptics respect the system setting automatically.

### 3.3 Bottom action bar (`m-bar`)
The sticky bottom action area rises last: opacity and offset 14 pt, 0.5 s, delay 0.18 s. Screens: `Account, BeforeYouStart, Camera, FormTemplates, LanguageRegion, MessageClient, NewAppointment, Permissions, RecordHistory, RecordTemplate, RecoveryKey, RunningLate, SessionPlan, SignIn, Waitlist` and the cancel/reschedule/request/export flows. Implement as `.motionBar()` on the `safeAreaInset(edge: .bottom)` content.

### 3.4 Sheets and scrims (`m-sheet`, `m-scrim`)
Use **system sheets** (they slide up with the system spring, with their own dim). Where a custom overlay is unavoidable (the in-flow confirmation sheets shown over a full-screen flow), use `fullScreenCover`/`.sheet` with `presentationBackground` and, if a manual dim is drawn, fade it 0.28 s with `.background(.regularMaterial)` instead of a 3 px blur. Prototype screens that use sheets: `Account, AddOns, Appointment, Bk-1-Page (language), Cl-7-MyData, ClientEdit, ClientProfile, Credentials, FollowUps, Help, Home, Onb-4-CustomService, Permissions, Privacy, Products, QuickReplies, RecordHistory, RecordTemplate, Tags, Team, WinBack`.

### 3.5 Switch and chips
The system `Toggle` already animates its knob; set the track tint to `sageStrong` and animate colour changes with `ease(0.3)`. Chips transition fill and text colour with `ease(0.24)`; the selection never changes instantly. Use `.contentTransition(.interpolate)` for numerals that change (counts, durations).

### 3.6 Success seal (`m-pop` + `m-check` + ring)
`SuccessSeal(size: 64 or 72)`: a filled circle (sage wash with sage ring, or graphite on Home-like contexts) containing a check.
- Circle: `scale 0.45 → 1.09 → 1` and opacity 0→1 over 0.62 s, **delay 0.1 s**, curve `soft`.
- Check: stroke `trim(from: 0, to: 0→1)` over 0.5 s, **delay 0.38 s**, `ease`. The check path (24-pt grid): `M5 12.5 L9.5 17 L19 7.5`, round caps and joins, stroke 2.2.
- Ring: one circle outline at the same size, scale 0.9→1.7, opacity 0.55→0, 1.1 s, **delay 0.45 s**, played once.
- Haptic `.success` at the circle's peak.
Screens that show it: `Bk-10-Review, Bk-8-Confirmed, BlockTime, BookingRequest, CancelAppointment, Cl-3-Rebook, Cl-4-Intake, Cl-5-CheckIn, Cl-6-Cancel, Cl-9-Reschedule, ExportAll, ExportRecord, ImportClients, Incident, NoShowMark, Onb-7-Ready, Permissions, RecoveryKey, Reschedule, RescheduleRequest` (the `Bk-*` and `Cl-*` ones are the web equivalents, see `10-WEB-BOOKING.md` §7). Check-only (no circle) on `FollowUps`.

### 3.7 Hero ambient (`m-hero`): Home "next up", `Plan`, `Waitlist`
The graphite hero card carries two slow-moving glows and one sheen.
- Glow drift: two radial gradients (rose top right, sage bottom left) that translate between (−6 %, −4 %) and (+6 %, +5 %) while scaling 1 → 1.12 over **14 s**, `easeInOut`, autoreverse, repeating.
- Mist (added 2026-10-11 at the owner's request): on the Home "next up" card a third, fainter orange radial cloud (16 % peak) wanders on its own path (19 s across, 13 s up and down, 9 s breathing, ±28 % and ±22 % of the card). Same limits as the drift; it freezes in place when the 60 s end. The text on the card is measured where the mist and the orange glow overlap.
- Sheen: a 34 %-wide diagonal highlight (−18° skew, white at 11 % opacity in the middle) that crosses the card **once**, 1.5 s, delay 0.55 s, when the screen first appears.
- Limits (deliberate refinements for battery and calm): run the glow only while the card is on screen and the scene is active; stop the drift after 60 s on screen; at most one hero animates at a time; no glow with Low Power Mode or Reduce Motion (static gradient instead).

### 3.8 Unread dot (`m-dot`)
A 8 pt rose dot with an expanding ring (box-shadow 0 → 8 pt, opacity 0.6 → 0) every 2.6 s. Used on `Home` ("Next up" label), `Onb-1-Welcome` and the Alerts tab indicator (the system tab badge is static; the in-screen dot pulses). Pulse for at most 10 s after the screen appears, then rest.

### 3.9 Navigation transitions
Forward push slides in from the trailing edge, back from the leading edge, tab switches crossfade. These are the system's behaviors (`NavigationStack`, `TabView`) and they mirror in right-to-left languages by themselves; **do not reimplement**. Any custom horizontal motion (a drawer, the before/after slider settle, a chip sliding) must use the `Directional.x(_:)` helper so the sign flips in Arabic; vertical motion (the arrival rise, sheets) is direction-neutral. Add a 0.2 s opacity crossfade to tab root content only if the system tab switch looks abrupt on device.

### 3.10 Micro-moments to add with the same curve (consistent with the prototype's spirit)
- List row insertion/removal: `.transition(.opacity.combined(with: .move(edge: .top)))` with `ease(0.3)`.
- Counts and times changing: `.contentTransition(.numericText())`.
- Skeleton → content: crossfade 0.28 s.
- Error banners: rise 14 pt + fade, 0.28 s.
- Photo capture: a white flash at 20 % opacity for 0.12 s and `.impact(.medium)`.
- Before/after slider: handle follows the finger 1:1; on release it settles with `ease(0.3)`; announces its value to VoiceOver.
- Waveform in `Tx-2-Listening`: bars driven by `AVAudioEngine` input level at ≤ 30 fps; with Reduce Motion show a static level meter.

## 4. Implementation notes (SwiftUI)

- `MotionArrivalModifier`: `@State var shown = false`; `.opacity(shown ? 1 : 0).offset(y: shown ? 0 : 14)`; `.onAppear { withAnimation(Motion.ease().delay(delay)) { shown = true } }` guarded by a per-navigation-instance flag so it does not replay.
- `SuccessSeal`: a `Shape` for the check with `animatableData` for `trim`; drive phases with `PhaseAnimator` or explicit `withAnimation` blocks with delays.
- `HeroGlow`: a `Canvas`/`RadialGradient` layer inside `.drawingGroup()`; animate with `withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true))` toggled `onAppear`/`onDisappear`.
- Prefer `phaseAnimator`, `keyframeAnimator` and `contentTransition` where they express the curve; fall back to `timingCurve`.
- Use `.compositingGroup()` for shadows under moving views. Avoid animating blur radius on large areas. Profile with Instruments (Animation Hitches) on a physical iPhone; any hitch > 8 ms in S12 is a bug.

## 5. Web

The client web app has the same motion language (CSS custom properties `--ease`, `--soft`, the same durations, the same stagger and press scale, the success seal) inside `@media (prefers-reduced-motion: no-preference)`. See `10-WEB-BOOKING.md` §7.

## 6. Reduce Motion, Reduce Transparency, Low Power

| Setting | Behavior |
|---|---|
| Reduce Motion | No offset/scale animations, no overshoot, no ambient loops, no sheen, no ring. Content appears at once or with a ≤ 0.2 s crossfade. The success check shows drawn. Haptics unaffected. |
| Reduce Transparency | Solid `surface` instead of materials; no blur. |
| Low Power Mode | Ambient loops off. |
| `-uiTesting` | All animations off (DEBUG). |

## 7. Tests

Unit-test the pure parts (stagger delay function, phase timing table, "should animate" decision matrix with Reduce Motion/Low Power/UI testing). A UI test with Reduce Motion enabled confirms the final state is present immediately (`waitForExistence` with a 1 s timeout). A Previews file in the Design Catalog replays each motion with a button.

## 8. Added 2026-10-12 (owner approved, "Motion 1 to 5")

Five additions to the kit, all through the same tokens and `MotionPolicy` (`DesignSystem/Motion/MotionChange.swift` holds
every decision, pure and tested; the modifiers only read it). Values added to `Motion`: `Duration.change` 0.3 s,
`Duration.reducedFade` 0.2 s, `Duration.flash` 0.12 s, `slideOffset` 24 pt, `flashOpacity` 0.2. The soft overshoot is
still used only by the success circle.

| Setting | What these additions do |
|---|---|
| Normal | `ease(0.3)` for changes in place, rows and settles; `ease(0.28)` for fades |
| Reduce Motion | numbers and rows crossfade (≤ 0.2 s); a block that changes place just is there; no slide, no flash; haptics stay |
| `-uiTesting`, `-uiReduceMotion` | no animation at all (the root also sets `isMotionDisabled`); `-uiAnimate` (DEBUG) keeps them on in a UI test so the animated paths can be exercised |

### 8.1 Numbers and times that change flow
`.motionNumber(value, countsDown:)`: `.contentTransition(.numericText(countsDown:))` plus `.animation(ease(0.3), value:)`.
It animates only when the value changes: the first text a view shows is never animated from zero (the arrival handles
that) and an unchanged value stays still. Reduce Motion: `.contentTransition(.opacity)` with `easeOut(0.2)`. Used on the
Home counters (`HomeCountRow`), the "in 1 h 20 min" countdown (counts down) and the time of the next-visit card, "x left"
of the rest of today, the week-glance tiles (`InsightTile`) and day counts (the bar glides with `motionSettle`), the Clients
count and the "not back" strip, the follow-up filter counts and "set aside" count, the registration counter, the import
plan figures, the session-plan steppers, the duration of New appointment and the Continue button of the Plan screen
(monthly to yearly). Not in the treatment flow's steps.

### 8.2 Rows that enter and leave
`.motionRows(ids:context:isReady:)` on the container and `.motionRow()` on each row: a row enters from above with a fade
and leaves with a fade and a slide (`.opacity` combined with `.move(edge: .top)`), the others close the gap, all with
`ease(0.3)`. Only inserted and removed identities animate (`MotionChange.rowsAnimation`): never while loading (`isReady`),
never for the first list a view sees, never when the `context` changes (another day, another filter: it is another
list), never when more than 12 identities change at once (a sync or an import), and a reorder alone only in a list of at
most 60. Reduce Motion: a 0.2 s crossfade; UI tests: instant. VoiceOver: when rows left, a `LayoutChanged` notification
is posted so the focus never stays on a row that is gone. Where: Home (hero, Today, rest of today, reach-out), Alerts and
inbox cards, the follow-up queue (snooze, dismiss, mark as sent, restore), the waitlist, the calendar day (timeline and
agenda list), the week (grid and list), and the Clients `List` (add and delete, with the list's own row animation under
the same curve; search, filters and loads are other contexts).

### 8.3 Confirmations you can feel
`SuccessSeal` (unchanged: pop 0.62 s with the soft overshoot after 0.1 s, check drawn in 0.5 s after 0.38 s, one ring,
`.success` haptic at the peak) now also confirms: the saved step of the treatment flow (size 56 above the badge). A brief
seal (`.confirmationSeal(whenIncreases:)`, `.confirmationSeal(whenTrue:)`, 56 pt, top of the screen, 1.5 s, fades in 0.28 s,
never takes a touch, hidden from VoiceOver) confirms a photo saved (the photos step), a message marked as sent (the
follow-up queue), an offer sent (the waitlist), and a booking or reschedule request accepted. The smaller inline
variant, `InlineCheck` (a check that draws in 0.5 s beside a label, `.success` haptic once), is next to "opened WhatsApp"
in the client message sheet and in the Save button of New client as it closes; Edit client has the haptic. Finishing the
closing path gives a `.success` haptic (the flow closes at once, so no seal). `ConfirmationCue` decides when (a count
that goes up, a flag that turns on, never the value a screen starts with). Reduce Motion: the check shows drawn at once,
no pop, no ring; haptics stay.

### 8.4 Camera and before/after
`.captureFlash(trigger:)`: 20 % white over the whole camera screen, fading out in 0.12 s (`easeOut`), with `.impact(.medium)`
at the shot. Reduce Motion and UI tests: no flash, the haptic stays. The framing reference fades in and out with its
switch (`ease(0.28)`, a 0.2 s crossfade with Reduce Motion), and so do its guide text and the opacity slider. The
before/after handle is the system slider (1:1 with the finger, adjustable and spoken by VoiceOver); on release it settles
with `ease(0.3)` on an end or on the middle when it is within 6 % of an end or 4 % of 0.5 (`BeforeAfterSnap`), and stays
where she left it otherwise.

### 8.5 Calendar
Changing the day or the week (arrows, strip, "Today", the date picker) brings the new content in from the side of travel:
24 pt and a fade in 0.3 s, the old content fades (`DaySlide`, `.motionDaySlide(travel:)`; forward comes from the
trailing edge, backward from the leading one, so Arabic mirrors through `Directional`; a mode switch has no direction and
only crossfades). The skeleton to content swap crossfades (0.28 s). The selected-day chip is one indicator that slides
between the days (`matchedGeometryEffect`, `ease(0.3)`); the "now" line (day and week) glides to its new place each minute; a visit
that is rescheduled glides to its new slot and a visit whose neighbour left widens (`motionSettle`, `ease(0.3)`, the
soft overshoot is not used). There is no drag-to-move gesture in the app (moving is the Reschedule sheet), so there is
nothing to follow the finger; if one is added it must call the same settle. Time-of-day rules and business-zone logic are
untouched (`docs/agent-notes/fix-reschedule-day.md`): only presentation changed.
