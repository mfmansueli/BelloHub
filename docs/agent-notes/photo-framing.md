# Photo framing reference (routine item 11): evaluation

Owner's ask (task file, item 11): evaluate an optional reference based on the previous photo, with an adjustable
overlay and simple position and distance guidance; preserve consents, the before/after comparison and private
storage; if it needs a big change to the camera, document it as a later stage.

**Verdict: a small, safe change. Implemented** on `routine-b` (commit "Camera: optional framing reference…"), with
the parts that need a real camera pipeline left for later (section 5).

## 1. What the camera code allows today

- `Screens/Treatment/Steps/CameraStepView` is the app's own camera (5.8): `CameraCapturing` (protocol) with
  `AVCameraCapture` and `CameraSessionHandle` behind it, the live preview in a 3:4 `CameraPreview`
  (`UIViewRepresentable` around the session's preview layer). The preview is a plain view, so SwiftUI can lay any view
  over it without touching the capture session.
- It already had a "Ghost" button: the latest photo of the *other* kind taken *in this visit*, from its 320 px
  thumbnail, at a fixed 35 % opacity. Nothing reached the photos of earlier visits.
- The capture returns bytes in memory (`capture() async throws -> Data`); the overlay is never part of them, because
  it is a SwiftUI view above the preview layer, not a layer of the session. So no change to `AVCameraCapture`, the
  photo pipeline (`PhotoProcessing`: 2048 px, EXIF stripped, thumbnail) or the vault was needed.
- `TreatmentRepository.photos(for:)` and `photoData(id:)` give every photo of a client and its decrypted bytes.

## 2. What was built

| Part | Where |
|---|---|
| Which photo is the reference: this visit's other kind first (an "after" lines up with today's "before"), else the latest earlier photo of the same kind (today's "before" with the last "before"), else the latest earlier photo | `Screens/Treatment/Support/FramingReferenceRules.swift` (pure, tested) |
| Loading it: the photo list and the full-size bytes from the vault, in memory only, handed to the screen | `Screens/Treatment/TreatmentFlowViewModel+FramingReference.swift` |
| "Show previous photo" (native switch, on by default when a reference exists), "How visible" (native slider, 15 to 60 %, default 35 %), rule-of-thirds guides, a two-line guide ("same spot on the lines, same distance, same light; it is not part of the new photo") | `CameraStepView`, `Treatment/Components/FramingGuides.swift` |

The old fixed "Ghost" toggle and its string are gone; its behavior (this visit's other kind) is rule 1 of the new one.
The full-size image is used instead of the 320 px thumbnail, because a thumbnail stretched over a 3:4 preview was too
blurred to line up an outline.

## 3. Privacy and consent

- **Storage stays private and encrypted.** Nothing new is stored: the reference is read from the vault (encrypted by
  the app, D26) into memory, shown, and dropped with the screen. No file, no cache, no camera roll, no pasteboard,
  never composited into the new photo, never sent anywhere (the camera has no network path).
- **Audience does not grow.** The professional already sees every photo of her client in the record; the reference
  shows one of them to her, on her own iPhone, while she photographs that same client. Photo visibility
  (`professionalOnly` / share with the client / portfolio, D2) only governs who *else* sees a photo; it is untouched,
  and the new photo still gets its own visibility on the review step, limited by the signed photo consent as before.
- **Consent is honored as before.** The flow still asks the visibility on review and `PhotoConsentRules` still
  downgrades it without a signed photo consent. A client without photo consent can still be photographed for the
  professional's private record (as today); the reference then comes from the same private photos.
- **Screen capture.** The camera already shows the live client; the reference adds an earlier picture of the same
  person to the same screen. No new exposure beyond what the camera screen has (the app's existing capture guard,
  `HiddenWhileCaptured`, is not applied to the live camera; unchanged).
- **The client in the chair** may see her previous photo on the professional's screen. That is the point of the
  comparison and the professional's decision; the switch turns it off.

## 4. Effort and risks

- Effort: one pure rule, one ViewModel extension, one decorative view, the camera screen's controls, three strings in
  fourteen localizations, unit tests (rules and ViewModel). No change to capture, processing, the vault or sync.
- Memory: one decrypted image up to 2048 px (about 400 KB compressed, a few MB decoded) while the camera is open.
  Acceptable on the iPhones iOS 26 supports.
- Misalignment: the preview layer fills its 3:4 frame (`resizeAspectFill`) and the reference fills the same frame
  (`DataImage` is `scaledToFill`), so both crop the same way; if the processed capture's framing differs from what the
  preview layer shows, the overlay can still be slightly offset. To check on a real
  iPhone (H19 camera check): take a "before", then an "after" with the reference, compare in the before/after view.
- Old photos taken in landscape or from the library: the overlay fills the 3:4 frame (cropped), which still gives a
  usable outline but not an exact one.

## 5. Later stage (not built; post-v1 list)

These need real camera work and a real iPhone, so they are recorded rather than built:

1. **Automatic position and distance hints** ("move closer", "tilt left") from Vision face or body landmarks compared
   between the reference and the live frame (`VNDetectFaceLandmarksRequest` on the preview's sample buffers): needs a
   video data output on the session (a change to `CameraSessionHandle`), throttling, and on-device-only processing.
2. **Edge-only overlay** (an outline extracted from the reference with Core Image) instead of a transparent photo,
   which hides less of the live picture.
3. **Same zoom and lens as last time**: store the capture's zoom factor and lens in the photo's metadata in the vault
   (a data-model addition) and restore them.
4. **Same exposure / white balance hints** from the stored values.
