# ISSUES.md

---

## 1: InteractiveCameraMatrixModifier should compute lookAt rotation when initializing from matrix

+++
status: closed
priority: medium
kind: bug
created: 2026-04-02T23:13:03Z
updated: 2026-04-03T00:24:35Z
closed: 2026-04-03T00:24:35Z
+++

When initializeStateFromMatrix() decomposes a pure translation matrix (e.g. simd_float4x4(translation: [0, 2, 6])), it gets identity rotation because there's no rotation encoded in the matrix. But the turntable target defaults to [0,0,0], so the camera should be looking AT the origin — not straight along -Z.

The fix: when initializing, compute a rotation quaternion that looks from the camera position toward the target, rather than using the decomposed rotation from the matrix. This would make all demos that use WorldView with a simple translation matrix automatically get a good initial camera angle looking at the scene.

Currently every demo in MetalSprocketsExamples that uses [0, 2, 6] as initial camera position shows the teapot in the upper half with empty space below because the camera looks level instead of down at the origin.

- `2026-04-03T00:24:35Z`: Compute lookAt rotation from camera position toward target instead of using decomposed matrix rotation

---

## 2: Remove or disable debug overlay tools from WorldView

+++
status: closed
priority: medium
kind: bug
created: 2026-04-03T00:05:57Z
updated: 2026-04-03T00:12:10Z
closed: 2026-04-03T00:12:10Z
+++

WorldView unconditionally adds 'Off' and 'Overlay' debug tools (lines 47-48 of WorldView.swift). These should either be removed, gated behind a parameter (like the interaction tools), or disabled by default so they don't appear in every app that uses WorldView.

- `2026-04-03T00:12:10Z`: Gated debug overlay tools behind .debugOverlay tool option, hidden by default

---

## 3: Make turntable target configurable in InteractiveCameraMatrixModifier

+++
status: closed
priority: low
kind: none
created: 2026-04-03T00:16:43Z
updated: 2026-07-20T18:56:09Z
closed: 2026-07-20T18:56:09Z
+++

The default target in InteractiveCameraMatrixModifier is hardcoded to [0,0,0]. Add a parameter to allow callers to specify a custom target point for the turntable orbit.

---

## 4: WorldView should expose turntable target parameter

+++
status: closed
priority: low
kind: none
created: 2026-04-04T01:32:13Z
updated: 2026-07-20T18:58:01Z
closed: 2026-07-20T18:58:01Z
+++

WorldView wraps InteractiveCameraMatrixModifier but doesn't expose the turntable target (pivot point). This means the turntable always orbits around the origin (0,0,0). Users who need to orbit around a different point (e.g. the centre of a scene) have to work around this by translating their geometry instead. WorldView should accept an optional target binding and pass it through to the turntable.

---

## 5: Investigate scroll wheel zoom not working with physical scroll wheel mice

+++
status: closed
priority: medium
kind: bug
created: 2026-04-09T20:24:50Z
updated: 2026-08-24T21:18:59Z
closed: 2026-08-24T21:18:59Z
+++

ScrollWheelModifier uses NSEvent.addLocalMonitorForEvents(.scrollWheel) to capture scroll events. Works with trackpad but reportedly doesn't work with physical scroll wheel mice. May be an issue with the momentumPhase filter:

```swift
guard event.momentumPhase.isEmpty || event.momentumPhase == .changed else {
    return
}
```

Physical scroll wheel mice may not set momentumPhase the same way as trackpads. Also the hasPreciseScrollingDeltas check determines the delta multiplier — scroll wheel mice use deltaY * 10 while trackpads use scrollingDeltaY.

Used in InteractiveCameraModifier via .onScrollWheel(delta:).

- `2026-08-24T21:18:59Z`: Removed momentum-phase filtering so physical wheel events are accepted.

---

## 6: MagnifyGesture zoom should use absolute magnification on visionOS

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-09T21:43:38Z
updated: 2026-08-24T21:18:59Z
closed: 2026-08-24T21:18:59Z
+++

InteractiveCameraModifier diffs MagnifyGesture magnification per-frame (zoomDelta - lastZoomDelta), giving tiny deltas even when hands move far apart. On visionOS with hand tracking, pinch-to-zoom feels like holding a distance — absolute magnification maps naturally to zoom distance. Per-frame deltas work for trackpad swiping but feel unresponsive with hand tracking. Consider using absolute magnification relative to start distance on visionOS, or at least a platform-specific multiplier.

- `2026-08-24T21:18:59Z`: visionOS magnification now sets distance relative to the gesture's starting distance.

---

## 7: TransformerProtocol should support different input and output types

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-12T04:51:55Z
updated: 2026-04-12T18:31:44Z
closed: 2026-04-12T18:31:44Z
+++

Currently TransformerProtocol is Value -> Value (same type in and out). The gesture manager prototype needed a separate GestureTransformerProtocol with Input -> Output. TransformerProtocol should be generalized to support different input/output types.

---

## 8: Rename TransformerProtocol.apply(to:) to transform(_:)

+++
status: closed
priority: low
kind: enhancement
created: 2026-04-12T05:00:26Z
updated: 2026-04-12T18:31:44Z
closed: 2026-04-12T18:31:44Z
+++

apply(to:) reads awkwardly. transform(_:) is more natural for a TransformerProtocol.

---

## 9: Unify Transformer and TransformerProtocol

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-12T05:37:42Z
updated: 2026-04-12T18:31:44Z
closed: 2026-04-12T18:31:44Z
+++

Two separate transformer protocols exist: Transformer (transform(_:)) and TransformerProtocol (apply(to:)). They're functionally identical with Input/Output associated types. Consolidate into one protocol. See also #8 for renaming apply(to:) to transform(_:).

---

## 10: Inspector and overlays take up too much space on iPadOS

+++
status: open
priority: medium
kind: bug
labels: effort:m, area:layout
created: 2026-04-12T20:36:52Z
updated: 2026-11-08T16:36:22Z
+++

Both .inspector() and .overlay() hint text may dominate the screen on iPadOS, especially in compact width. Inspector likely takes over the full screen instead of appearing as a sidebar. The hint overlay at the bottom could also obscure too much content. Need to test on iPad and consider adaptive layouts or popovers.

- `2026-08-25T21:11:58Z`: Inspected all inspector and hint-overlay call sites across the demo views. Punting: the report is speculative and does not identify a reproducing demo, iPad size class, or desired compact presentation. Can you provide a screenshot/repro for one demo and confirm whether compact width should hide hints, use a popover, or present a sheet?
- `2026-11-07T23:28:19Z`: Re-checked during an autonomous run: no new info since the previous punt. Still punting: the compact-width presentation (hide hints, popover, or sheet) is a design decision. Unblocker: pick one, or share an iPad screenshot of a demo where it is a problem.
- `2026-11-08T16:39:51Z`: Autonomous run: punting. Tried locating the .inspector()/hint overlay usage; the fix needs a layout decision (sidebar vs popover vs sheet in compact width) and verification on an iPad or iPad simulator in compact and regular widths, which I can't judge from code alone. Unblocker: say which presentation you want in compact width (e.g. inspector → sheet, hints → collapsible), or confirm I may run the demo in the iPad simulator to capture screenshots first.

---

## 11: ImplicitStrongCapture warnings in WASDController mouse notification tasks

+++
status: closed
priority: low
kind: bug
created: 2026-07-20T18:15:06Z
updated: 2026-07-20T18:17:22Z
closed: 2026-07-20T18:17:22Z
+++

Building emits two compile warnings in Sources/Interaction3D/FPV/WASDController.swift (lines ~106 and ~114):

    'weak' ownership of capture 'self' differs from implicitly-captured strong reference in outer scope [#ImplicitStrongCapture]

In setupMouseHandling(), the outer `mouseObservationTask = Task { ... }` implicitly captures self strongly, while the two inner `Task { [weak self] in ... }` closures capture it weakly. The weak captures are therefore ineffective for avoiding a retain, and the compiler flags the mismatch.

---

## 12: ToolPicker uses AnyView-based type erasure throughout

+++
status: closed
priority: low
kind: enhancement
labels: effort:l
created: 2026-07-20T18:32:49Z
updated: 2026-08-25T21:26:05Z
closed: 2026-08-25T21:26:05Z
+++

Support/ToolPicker.swift stores tool labels and modifiers as AnyView/AnyViewModifier (~8 uses) and reduces modifiers via nested AnyView wrapping. The house rules discourage AnyView; heterogeneous storage is a semi-legitimate use, but labels could be generic or @ViewBuilder-based. Non-trivial refactor.

- `2026-08-25T21:13:45Z`: Inspected ToolPicker's storage and public tool APIs. Punting: heterogeneous arbitrary View labels and ViewModifier factories require type erasure, so removing AnyView means narrowing the public API or redesigning modifier composition with unclear compatibility impact. Should labels be limited to LocalizedStringKey/Text, or is preserving arbitrary View labels required?
- `2026-08-25T21:26:05Z`: Closed as invalid after API review: ToolPicker intentionally supports arbitrary SwiftUI view labels in a heterogeneous runtime collection. AnyView is the appropriate standard type erasure; alternatives would only recreate type erasure, restrict label shapes, or break dynamic registration.

---

## 13: Multi-property computed 'some View' sections should be extracted into View structs

+++
status: closed
priority: low
kind: enhancement
created: 2026-07-20T18:32:49Z
updated: 2026-07-20T18:47:40Z
closed: 2026-07-20T18:47:40Z
+++

Per SwiftUI house rules, computed some View properties that read more than a couple of properties should be their own View structs. Candidates: InteractiveCameraDebugView (stateSection, modeSection, transformOptionsSection), FlightSimControlsView.infoPanel, FPVFlightSimModifier.controlsPanel.

---

## 14: WorldView and tool modifiers lack #Previews

+++
status: closed
priority: low
kind: enhancement
labels: effort:s
created: 2026-07-20T18:32:49Z
updated: 2026-08-25T21:13:35Z
closed: 2026-08-25T21:13:35Z
+++

Views/WorldView.swift and the RotationWidget/debug-overlay tool modifiers have no #Preview. They need a ProjectionProtocol binding and camera plumbing, so a preview requires small fixture helpers.

---

## 15: Turntable/WorldView controls missing accessibility labels

+++
status: closed
priority: medium
kind: task
labels: accessibility, effort:m
created: 2026-08-09T16:23:32Z
updated: 2026-08-25T21:12:48Z
closed: 2026-08-25T21:12:48Z
+++

The Turntable camera control popup and related WorldView interaction controls have no accessibility labels. Need .accessibilityLabel() on the camera mode picker and any other interactive elements.

This blocks automated UI testing via steveo in downstream apps.

Reported downstream: MetalSprocketsExamples#368.

- `2026-08-25T21:12:48Z`: Regression test exempt: accessibility metadata is exposed by SwiftUI at runtime rather than as a unit-testable value. Added an explicit accessibility label to every ToolPicker group picker; its options already use their visible labels.

---

## 16: Scroll gestures affect views in other windows

+++
status: closed
priority: medium
kind: bug
created: 2026-08-24T20:05:06Z
updated: 2026-08-24T21:18:59Z
closed: 2026-08-24T21:18:59Z
+++

## What’s wrong

Scroll-wheel and trackpad gestures captured by `onScrollWheel` can update an interactive camera when the gesture occurs over another window or over a different view. Event ownership by window alone is insufficient: handling must also be scoped to the specific attached view under the pointer.

## Reproduction

1. Open two app windows, with an interactive camera view in at least one window.
2. Place the pointer over the other window or over a view outside the interactive camera.
3. Perform a trackpad Page Up/Page Down scroll gesture.

## Expected

Only the interactive camera view under the pointer responds.

## Actual

Interactive camera views elsewhere in the app can respond to the gesture.

- `2026-08-24T21:18:59Z`: Scoped scroll events to their originating window and attached view.

---

## 17: Scroll-wheel zoom responds outside the interactive view

+++
status: closed
priority: medium
kind: bug
created: 2026-08-25T20:48:33Z
updated: 2026-08-25T20:53:04Z
closed: 2026-08-25T20:53:04Z
+++

## What is wrong

A view with Interaction3D scroll-wheel zoom responds to scroll events when the pointer is over a different scrollable view in the same window. Both views react to one event: the frontmost scroll view scrolls and the interactive camera zooms.

## Reproduction

1. Add an Interaction3D camera view and a separate scrollable view to the same window.
2. Place the pointer over the scrollable view.
3. Scroll with a trackpad or mouse.

## Expected

Only the scrollable view under the pointer scrolls. The camera view does not zoom.

## Actual

The scrollable view scrolls and the camera view zooms at the same time.

- `2026-08-25T20:53:04Z`: Replaced the window-wide event monitor with normal AppKit scroll-wheel hit testing, so only the view under the pointer receives zoom input.

---

## 18: Game-controller observers retain their controller indefinitely

+++
status: closed
priority: medium
kind: bug
labels: effort:s
created: 2026-08-25T20:55:25Z
updated: 2026-08-25T21:09:13Z
closed: 2026-08-25T21:09:13Z
+++

## What is wrong

The game-controller connection and disconnection observer tasks promote their weak controller reference to a strong reference before entering an indefinite notification loop. Each controller owns those tasks, so the tasks keep the controller alive and its deinitializer cannot cancel them or finish its event stream.

## Reproduction

1. Create a `GameControllerMovementController`.
2. Release every external reference to it while no connection notification stream has ended.
3. Observe that the controller is not deallocated and its observer tasks remain active.

## Expected

Releasing the last external reference deallocates the controller and stops its tasks.

## Actual

The observer tasks retain the controller for the lifetime of the notification streams.

---

## 19: SwiftUI observable models are not main-actor isolated

+++
status: closed
priority: high
kind: bug
labels: effort:m
created: 2026-08-25T20:57:00Z
updated: 2026-08-25T21:07:46Z
closed: 2026-08-25T21:07:46Z
+++

## What is wrong

`MovementController` and `ToolPickerModel` are Observation models consumed and mutated by SwiftUI, but the package target does not use main-actor default isolation and neither class declares main-actor isolation. Their mutable properties can therefore be accessed outside the UI actor, allowing races with SwiftUI reads and updates.

## Expected

Observable UI model state is isolated to the main actor.

## Actual

The models expose mutable observed state without actor isolation.

- `2026-08-25T21:07:46Z`: Regression test exempt: actor isolation is enforced at compile time; xcb test confirms all affected call sites compile under strict concurrency.

---

## 20: Canvas views use redundant GeometryReader wrappers

+++
status: closed
priority: low
kind: task
labels: effort:xs
created: 2026-08-25T20:57:01Z
updated: 2026-08-25T21:16:20Z
closed: 2026-08-25T21:16:20Z
+++

## What is wrong

The turntable demos and `HorizonCue` wrap `Canvas` in `GeometryReader` but do not use the geometry proxy. `Canvas` already receives its available size, so the wrappers add layout complexity and an unnecessary view layer without affecting rendering.

## Expected

Canvas-based views use the size supplied by `Canvas` directly.

## Actual

Unused geometry readers wrap the canvases.

---

## 21: ForEach rows use copied enumerated collections and positional identity

+++
status: closed
priority: medium
kind: bug
labels: effort:s
created: 2026-08-25T20:57:01Z
updated: 2026-08-25T21:11:35Z
closed: 2026-08-25T21:11:35Z
+++

## What is wrong

`VectorEditor` and `TransformerParameterEditor` eagerly wrap enumerated collections in `Array` or identify rows by enumeration offsets. Swift 6.2 enumerated collections can be passed directly, and offsets identify positions rather than elements. Reordering or inserting elements can associate SwiftUI row state with the wrong element; the array wrapper also allocates during body evaluation.

## Expected

ForEach receives the collection directly and uses stable element identity.

## Actual

Rows use copied collections or positional offsets as identity.

- `2026-08-25T21:11:35Z`: Regression test exempt: this is SwiftUI row identity and allocation behavior without a unit-testable output; xcb test verifies the direct enumerated collections and element identity key paths compile.

---

## 22: Canvas widgets are inaccessible to assistive technologies

+++
status: closed
priority: high
kind: bug
labels: accessibility, swiftui
created: 2026-08-26T13:55:39Z
updated: 2026-08-26T14:07:20Z
closed: 2026-08-26T14:07:20Z
+++

## What is wrong

The public canvas-based widgets expose visual state without accessibility labels, values, representations, or decorative-element handling. VoiceOver users cannot identify or understand the artificial horizon, compass, horizon cue, map, speedometer, measurement dial, or rotation widget.

## Expected

Each widget communicates its purpose and current value through accessibility APIs.

- `2026-08-26T14:07:20Z`: Implemented and validated with SwiftLint, macOS/iOS builds, and package tests.

---

## 23: Tool picker relies on pervasive AnyView type erasure

+++
status: closed
priority: medium
kind: enhancement
labels: swiftui, architecture
created: 2026-08-26T13:55:39Z
updated: 2026-08-26T14:19:31Z
closed: 2026-08-26T14:19:31Z
+++

## What is wrong

ToolPicker erases tool labels, modifiers, and composed content with AnyView. This hides view structure from SwiftUI and makes identity, invalidation, and layout behavior harder to reason about.

## Expected

The tool picker preserves useful SwiftUI view structure without pervasive type erasure.

- `2026-08-26T14:19:31Z`: Duplicate of #12, which reviewed this exact AnyView-based ToolPicker design and closed it as intentional type erasure for heterogeneous runtime tools.

---

## 24: Form controls use hand-built label and value rows

+++
status: closed
priority: low
kind: enhancement
labels: swiftui
created: 2026-08-26T13:55:39Z
updated: 2026-08-26T14:07:20Z
closed: 2026-08-26T14:07:20Z
+++

## What is wrong

Camera lens controls and transformer parameter controls manually compose labels, spacers, values, and controls in HStacks. Their alignment and adaptive behavior do not consistently follow Form conventions.

## Expected

Label-and-value controls align and adapt consistently with native Form rows.

- `2026-08-26T14:07:20Z`: Implemented and validated with SwiftLint, macOS/iOS builds, and package tests.

---

## 25: Flight simulator controls do not adapt to available space

+++
status: closed
priority: medium
kind: bug
labels: swiftui, layout
created: 2026-08-26T13:55:39Z
updated: 2026-08-26T14:07:20Z
closed: 2026-08-26T14:07:20Z
+++

## What is wrong

FlightSimControlsView uses several fixed widths and heights with explicit spacers. The public view does not adapt well to narrow windows, larger text, or varying container sizes, which can clip or misalign its instruments.

## Expected

The control layout adapts to its container and text size without clipping or overflow.

- `2026-08-26T14:07:20Z`: Implemented and validated with SwiftLint, macOS/iOS builds, and package tests.

---

## 26: InteractiveCamera bypasses shared composable gesture components

+++
status: closed
priority: high
kind: enhancement
labels: architecture, testability, camera, effort:l
created: 2026-08-26T14:15:33Z
updated: 2026-08-26T15:25:27Z
closed: 2026-08-26T15:25:27Z
+++

## What is wrong

InteractiveCameraModifier implements its own drag, pan, scroll, magnification, delta, and reset behavior instead of composing the gesture components exposed by GestureManager. The two paths can drift: scroll-wheel scoping and pinch scaling have already behaved differently between them. Camera-specific orchestration is also difficult to test because shared gesture semantics are embedded in SwiftUI callbacks.

## Expected

InteractiveCamera composes the same reusable drag, scroll, magnify, accumulation, and transformation parts used elsewhere. Platform adapters can remain separate, and camera-specific orchestration stays thin and independently testable.

## Proposed fix (per user)

Keep the existing `interactiveCamera(...)` API as a convenience composition. Extend the shared drag primitive to expose start location, current location, and translation. Build thin turntable and arcball rotation adapters on that primitive. Compose pan, scroll zoom, and magnify zoom from the existing transformed gesture components, with independent scroll and magnify scaling because their raw units differ. Remove the duplicate delta bookkeeping and `applyInteraction()` state machine from `InteractiveCameraModifier`. Add boundary tests for scroll/pinch parity, gesture completion, and both rotation modes.

- `2026-08-26T15:25:27Z`: Refactored InteractiveCamera to compose shared core drag, scroll, and magnify components while preserving its public API. Added internal drag positions, thin camera adapters, independent zoom scaling, and compatibility/rotation/completion tests. Strict SwiftLint, package tests, and macOS/iOS builds pass.

---

## 27: FPV movement depends on hardware polling cadence and wall-clock timing

+++
status: closed
priority: high
kind: bug
labels: architecture, testability, fpv, effort:l
created: 2026-08-26T14:15:33Z
updated: 2026-08-26T14:57:41Z
closed: 2026-08-26T14:57:41Z
+++

## What is wrong

The FPV path couples keyboard, mouse, and game-controller polling with event reduction, elapsed-time calculation, and pose integration. Continuous movement advances when events arrive, so observable motion can vary with adapter scheduling and polling cadence. Stream lifetime and cancellation also span several owners.

## Expected

Given the same input sequence and elapsed time, FPV movement produces deterministic pose updates independent of hardware polling cadence.

- `2026-08-26T14:57:41Z`: Separated input event reduction from explicit elapsed-time movement updates, added a continuous-clock integration loop, and added deterministic boundary tests. SwiftLint, package tests, and iOS build pass.

---

## 28: Camera matrix binding does not have a testable synchronization boundary

+++
status: closed
priority: high
kind: bug
labels: architecture, testability, camera, effort:m
created: 2026-08-26T14:15:33Z
updated: 2026-08-26T14:52:46Z
closed: 2026-08-26T14:52:46Z
+++

## What is wrong

InteractiveCameraMatrixModifier keeps matrix/state conversion and lifecycle synchronization private inside SwiftUI callbacks. Matrix import is gated after initial appearance, so later external matrix replacements are not observed. Degenerate distance and pole-aligned camera cases are also unverified.

## Expected

Camera matrices and interaction state remain synchronized across initialization, external updates, repeated interaction, and degenerate orientations.

- `2026-08-26T14:52:46Z`: Added a pure camera matrix synchronization boundary, observed external matrix and target changes, handled degenerate orientations, and added boundary tests. SwiftLint, package tests, and iOS build pass.

---

## 29: WorldView silently assumes a 60-degree flight simulation field of view

+++
status: closed
priority: medium
kind: enhancement
labels: testability, projection, fpv, effort:s
created: 2026-08-26T14:15:33Z
updated: 2026-08-26T15:10:07Z
closed: 2026-08-26T15:10:07Z
+++

What is wrong

WorldView downcasts its projection to PerspectiveProjection for FPV flight simulation. For every other projection type it silently substitutes a 60-degree field of view, so the horizon overlay can disagree with the rendered projection.

Expected

WorldView derives the field of view from PerspectiveProjection or accepts an explicit override. When neither is available, the FPV flight simulation tool is unavailable rather than using an invented projection value.

- `2026-08-26T15:10:07Z`: WorldView now derives perspective field of view, accepts an explicit override for other projections, and disables FPV Flight Sim when no field of view is available. Added capability tests; strict SwiftLint, package tests, and macOS/iOS builds pass.

---

## 30: Software renderer accepts invalid and partially projected geometry

+++
status: closed
priority: medium
kind: enhancement
labels: testability, rendering, projection, effort:s
created: 2026-08-26T14:15:33Z
updated: 2026-08-26T15:16:51Z
closed: 2026-08-26T15:16:51Z
+++

What is wrong

SoftwareRendererContext accepts points behind the camera because it checks abs(w), and path(polygon:) drops unprojectable vertices before connecting the remainder. This can create a valid-looking path from invalid geometry.

Expected

Pure projection behavior has a testable SIMD boundary. Invalid or behind-camera points fail projection, screen mapping is deterministic, and a polygon is rejected in full when any vertex cannot be projected. Full frustum clipping is out of scope until arbitrary partially visible meshes require it.

- `2026-08-26T15:16:51Z`: Added a pure SIMD projection boundary, reject non-finite and behind-camera points, and reject polygons when any vertex cannot project. Preserved CGPoint and Path adapters; full frustum clipping remains out of scope. Strict SwiftLint, package tests, and macOS/iOS builds pass.

---

## 31: Turntable orbit axis is fixed to world Y

+++
status: closed
priority: medium
kind: enhancement
created: 2026-09-30T18:21:50Z
updated: 2026-09-30T18:33:10Z
closed: 2026-09-30T18:33:10Z
+++

TurntableTransformer always yaws around world Y and pitches around world X. Apps with a Z-up world (astronomy, CAD, most GIS) must convert the rotation quaternion to and from their own frame with an axis-swap adapter.

Found while evaluating Interaction3D for SolarSystem, whose camera works in the ecliptic frame (Z up).

Expected: a way to configure the up axis (default Y), so that turntable yaw and pitch are relative to it.

- `2026-09-30T18:33:10Z`: Implemented; see commit.

---

## 32: No turntable binding for yaw and pitch angles

+++
status: closed
priority: low
kind: enhancement
created: 2026-09-30T18:21:50Z
updated: 2026-09-30T18:33:10Z
closed: 2026-09-30T18:33:10Z
+++

InteractiveCameraModifier binds only a simd_quatf rotation. Apps that already store the camera as yaw and pitch angles must write a two-way quaternion adapter and duplicate the decomposition that TurntableTransformer does internally.

Found while evaluating Interaction3D for SolarSystem, which stores orbitYaw and orbitPitch as Double radians.

Expected: a turntable variant that binds yaw and pitch directly. The library still owns sensitivity, clamping and momentum.

- `2026-09-30T18:33:10Z`: Implemented; see commit.

---

## 33: Zoom is additive only, with a fixed 0.01 minimum distance

+++
status: closed
priority: medium
kind: enhancement
created: 2026-09-30T18:21:50Z
updated: 2026-09-30T18:33:10Z
closed: 2026-09-30T18:33:10Z
+++

Scroll and magnify zoom add a fixed delta to distance, and InteractiveCameraModifier clamps distance to at least 0.01. For scenes whose scale spans orders of magnitude, one zoom step is either too small far away or too large close up, and the min/max limits cannot be set.

Found while evaluating Interaction3D for SolarSystem, whose orbit distance ranges from 1.01 to 1e6 body radii.

Expected: a configurable zoom model (for example additive or multiplicative/log-scale) and configurable minimum and maximum distance.

- `2026-09-30T18:33:10Z`: Implemented; see commit.

---

## 34: Pan cannot be turned off

+++
status: closed
priority: low
kind: enhancement
created: 2026-09-30T18:21:51Z
updated: 2026-09-30T18:33:10Z
closed: 2026-09-30T18:33:10Z
+++

InteractiveCameraModifier always installs Command-drag pan, which moves the target point. Apps whose target is fixed (orbit a selected object) must pass a constant binding for target and still get a gesture that does nothing.

Found while evaluating Interaction3D for SolarSystem, where the target is always a body.

Expected: an option to disable pan.

- `2026-09-30T18:33:10Z`: Implemented; see commit.

---

## 35: No look-around mode for a camera at a fixed position

+++
status: closed
priority: low
kind: enhancement
created: 2026-09-30T18:21:51Z
updated: 2026-09-30T18:33:10Z
closed: 2026-09-30T18:33:10Z
+++

The controllers either orbit a target (turntable, arcball) or move the camera (FPV). There is no mode where the camera stays at a fixed position and drag only changes where it looks, with configurable altitude clamps. FPV has parts of this but also does movement.

Found while evaluating Interaction3D for SolarSystem, whose surface mode stands on a planet and looks around (azimuth and altitude).

Expected: a look-around mode that binds a view direction (or azimuth/altitude) and clamps altitude.

- `2026-09-30T18:33:10Z`: Implemented; see commit.

---

## 36: Interaction state is Float only

+++
status: closed
priority: low
kind: enhancement
created: 2026-09-30T18:21:51Z
updated: 2026-09-30T18:33:10Z
closed: 2026-09-30T18:33:10Z
+++

InteractionState stores distance and target as Float. At large scales (planetary or astronomical distances) Float loses precision in distance and target, so apps must keep their own Double state and convert.

Found while evaluating Interaction3D for SolarSystem, which uses Double km positions.

Expected: generic or Double-precision distance and target. Rotation can stay Float.

- `2026-09-30T18:33:10Z`: Implemented at the view-modifier level: interactiveCamera accepts Float or Double distance and target. InteractionState and the transformers remain Float.

---

## 37: visionOS is not a declared platform

+++
status: closed
priority: low
kind: task
labels: platforms
created: 2026-10-05T16:00:33Z
updated: 2026-10-07T17:22:24Z
closed: 2026-10-07T17:22:24Z
+++

Package.swift declares only macOS 26 and iOS 26. Apps that target visionOS and depend on Interaction3D (e.g. MetalSprocketsGLTF's GLTFViewer demo) have no declared minimum or support for that platform.

---

## 38: Let callers veto camera drags at drag start (hands off for gizmos)

+++
status: closed
priority: high
kind: feature
created: 2026-10-22T21:57:51Z
updated: 2026-10-23T12:49:55Z
closed: 2026-10-23T12:49:55Z
+++

Camera controls (`interactiveCamera`, and the drag modifiers in Controllers/GestureManager.swift) attach `simultaneousGesture` drags. When the view also has its own drag, for example a transform gizmo in SceneSprockets, both run: the camera orbits while the gizmo handle moves. Callers can not tell Interaction3D "hands off, this drag is ours".

`GestureManager` already decides per drag at the start (`claimState`: claimed or rejected from the modifier keys). Add a caller hook into that decision, for example:

```swift
view.interactiveCamera(cameraMatrix: $matrix)
    .interactionDragFilter { startLocation in !gizmo.hitTest(startLocation) }
```

- Evaluated once per drag, at the first change, with `startLocation` in the view's coordinate space.
- False rejects the whole drag (rotate, pan, and anything else driven by drags), the same as a modifier mismatch today.
- An environment value, so it reaches all camera modifiers at once and works with other controllers (FPV, rotation widget).
- Maybe also a way to check scroll and magnify, though those rarely conflict.

Needed by SceneSprockets (#173, transform gizmo needs a hover before a click) and SceneSprocketsComposer, which turned Interaction3D camera control off and wrote its own because of this conflict.

- `2026-10-23T12:49:55Z`: Done: interactionDragFilter (e9fa23de), interactionScrollFilter + interactionMagnifyFilter (88d9e330).

---

## 39: FPV movement cannot start from an existing camera pose

+++
status: closed
priority: medium
kind: enhancement
labels: fpv, effort:m
created: 2026-11-07T23:15:42Z
updated: 2026-11-07T23:29:08Z
closed: 2026-11-07T23:29:08Z
+++

FPVMovementController always starts at the origin with zero yaw and pitch, and FPVMovementModifier writes its transform into the bound cameraMatrix at once (onChange with initial: true). A host view that already has a camera, such as an orbit camera from interactiveCamera(cameraMatrix:), jumps to the origin when FPV is added. External changes to the bound matrix are also not read back, so FPV and another camera control on the same binding fight each other.

Seen while adding fly navigation to SceneSprockets' SceneView (SceneSprockets #313).

---

## 40: FPVMovementModifier is macOS-only and adds toolbar items to the host window

+++
status: closed
priority: medium
kind: enhancement
labels: fpv, effort:m
created: 2026-11-07T23:15:42Z
updated: 2026-11-07T23:32:26Z
closed: 2026-11-07T23:32:26Z
+++

FPVMovementModifier and WASDController are inside #if os(macOS). There is no FPV keyboard or game controller movement on iOS, iPadOS or visionOS, although GameControllerMovementController works on those platforms.

FPVMovementModifier also always adds three ToolbarItems (Enable/Disable Mouse ⌘T, Capture/Release Mouse ⌘M, Reset to Origin ⌘0) and their keyboard shortcuts. A library view that embeds FPV, such as a scene view in a host app, gets these buttons and shortcuts in the app's toolbar without asking for them.

- `2026-11-07T23:19:54Z`: Related: #41 (focus handling) and #42 (keyboard controls) touch the same WASDController/FPVMovementModifier code.

---

## 41: WASDController reads keys even when the FPV view does not have focus

+++
status: closed
priority: high
kind: bug
labels: fpv, effort:s
created: 2026-11-07T23:15:42Z
updated: 2026-11-07T23:26:54Z
closed: 2026-11-07T23:26:54Z
+++

WASDController polls GCKeyboard.coalesced every 16 ms. It does not depend on SwiftUI focus, so WASD moves the FPV camera while the user types in a text field or uses another view in the same app. FPVMovementModifier makes the view focusable, but key polling does not check that focus.

---

## 42: FPV has no keyboard controls for vertical movement, looking, or speed

+++
status: closed
priority: medium
kind: enhancement
labels: fpv, effort:s
created: 2026-11-07T23:15:42Z
updated: 2026-11-07T23:28:19Z
closed: 2026-11-07T23:28:19Z
+++

Keyboard FPV input supports only WASD for planar movement. Missing compared with common fly-camera controls:
- Up and down from the keyboard (for example Q/E). Altitude comes only from a game controller.
- Turn and look from the keyboard (for example arrow keys). Looking needs mouse capture or a controller.
- A fast-move modifier (for example Shift or a stick click).

SceneSprockets #313 needed all three.

---

## 43: fpvMovement has no way to set movement speed

+++
status: closed
priority: medium
kind: enhancement
labels: fpv
created: 2026-11-08T06:33:02Z
updated: 2026-11-08T06:41:08Z
closed: 2026-11-08T06:41:08Z
+++

`View.fpvMovement(cameraMatrix:)` (`FPVMovementModifier`) owns its `FPVMovementController` as private state, so callers cannot change `speed` (fixed at 10 units/s), `fastSpeedMultiplier` (4), `mouseSensitivity`, or the turn speeds.

This makes the modifier impractical for large scenes. In CBTerrain (a 16 km terrain in meters), crossing the world at the maximum 40 m/s takes about 7 minutes.

`FPVFlightSimModifier` exposes a speed slider in its controls popover, but only in the range 1...50, and only through its UI.

Seen with 0.1.16; main (cc8f4e5) has the same API.

---

## 44: FPV mouse look is off by default and needs a ⌘T toolbar toggle

+++
status: closed
priority: medium
kind: enhancement
labels: fpv
created: 2026-11-08T06:35:34Z
updated: 2026-11-08T06:41:08Z
closed: 2026-11-08T06:41:08Z
+++

Mouse look in `fpvMovement` and `FPVFlightSimModifier` does nothing until the user presses ⌘T or the toolbar's "Enable Mouse" button (`FPVMovementController.mouseTrackingEnabled` defaults to false). Capture is a second step (⌘M), and ⌘0 resets.

These window-level shortcuts and toolbar items are added to the host app, can collide with its own shortcuts (⌘T and ⌘M are common system/app shortcuts), and are not discoverable. Hosts have no API to turn mouse look on.

Seen in CBTerrain with 0.1.16; main (cc8f4e5) still defaults to off. On main the toolbar is opt-in via `showsControls`, which leaves no way at all to enable mouse look in the plain modifier.

## Proposed fix (per Jonathan)
Enable mouse look by default and remove the ⌘T toggle and related shortcuts.

---

## 45: FPV mouse look reacts to mouse movement outside the view

+++
status: closed
priority: medium
kind: bug
labels: fpv
created: 2026-11-08T06:35:34Z
updated: 2026-11-08T06:46:18Z
closed: 2026-11-08T06:46:18Z
+++

`WASDController` reads mouse deltas from `GCMouse.mouseInput.mouseMovedHandler`, which reports all mouse movement system-wide. Once mouse look is enabled, the camera turns whenever the mouse moves, even when the cursor is outside the FPV view, the window is not key, or another app is frontmost. Keyboard input is gated on view focus (#41); mouse input is not.

Steps:
1. Use `fpvMovement` in a window, enable mouse look (⌘T).
2. Move the cursor out of the window, or switch to another app, and move the mouse.

Expected: the camera ignores the mouse unless the view is focused (or the mouse is captured).
Actual: the camera keeps turning.

Found by code reading (WASDController.registerMouse); not yet confirmed at runtime.

- `2026-11-08T06:46:18Z`: Won't fix: mouse look is intentionally global.

---

## 46: FPV mouse look axes may be inverted on the GCMouse path

+++
status: closed
priority: low
kind: bug
labels: fpv
created: 2026-11-08T06:35:34Z
updated: 2026-11-08T06:41:08Z
closed: 2026-11-08T06:41:08Z
+++

`FPVMovementController.process(event:)` applies mouse deltas as `yaw += deltaX * mouseSensitivity` and `pitch -= deltaY * mouseSensitivity`. The transform is built from a +Y-axis yaw rotation, where positive yaw turns left, so moving the mouse right appears to turn the camera left. `GCMouse` reports +Y for upward movement, so the pitch sign may also be reversed; the `NSEvent` fallback path reports +Y downward, so the two paths may disagree with each other.

Found by code reading; not yet confirmed at runtime. Reported as "mouse tracking is borked" in CBTerrain.

---

## 47: WASDController prints debug messages to the console

+++
status: closed
priority: low
kind: bug
labels: fpv
created: 2026-11-08T06:35:35Z
updated: 2026-11-08T06:41:08Z
closed: 2026-11-08T06:41:08Z
+++

`WASDController` calls `print` for routine mouse setup: "Mouse connected via notification", "No mouse/trackpad found - setting up NSEvent monitor", "Registering mouse handlers", "Mouse input available", "Mouse input is ready", "No mouse input available on this mouse device". These appear in every host app's console.

---

## 49: FPV W/S movement stays on the horizontal plane with no free-flight option

+++
status: closed
priority: medium
kind: enhancement
labels: fpv
created: 2026-11-08T06:44:51Z
updated: 2026-11-08T06:46:57Z
closed: 2026-11-08T06:46:57Z
+++

`FPVMovementController.applyContinuousInputs` builds the movement basis from yaw only (`forward = (-sin yaw, 0, -cos yaw)`), so W/S never change altitude even when looking up or down; only Q/E move vertically. This walking-style movement is a good default, but there is no way to choose free flight, where W/S move along the full view direction (including pitch). CBTerrain's original fly camera moved along the view direction, and losing it makes descending toward terrain awkward.

Expected: a setting (e.g. on `FPVMovementSettings`) to move along the view direction; horizontal-plane movement stays the default.
Actual: movement is always horizontal.

---

## 50: Holding Shift with WASD/QE in the FPV view makes the system beep

+++
status: closed
priority: medium
kind: bug
labels: fpv
created: 2026-11-08T06:44:51Z
updated: 2026-11-08T06:46:57Z
closed: 2026-11-08T06:46:57Z
+++

`disableWASDKeys()` swallows key presses with `onKeyPress(keys:)` for the lowercase `KeyEquivalent`s w, a, s, d, q, e plus the arrows. With Shift held (fast movement), the presses arrive as uppercase characters (W, A, ...), don't match, fall through unhandled, and AppKit beeps on every repeat.

Steps:
1. Focus a view using `fpvMovement`.
2. Hold Shift and W.

Expected: fast forward movement, no sound.
Actual: fast movement plus repeated system beeps.

The uppercase-character cause is inferred from the code, not confirmed with a key log.

---

## 51: FPV view needs a click before keyboard movement works

+++
status: closed
priority: medium
kind: bug
labels: fpv
created: 2026-11-08T06:49:21Z
updated: 2026-11-08T06:50:54Z
closed: 2026-11-08T06:50:54Z
+++

`FPVMovementModifier` makes its content focusable and gates keyboard input on its private `@FocusState` (#41), but nothing gives the view focus when it appears. After launch, WASD/QE do nothing until the user clicks the view.

The host can't fix this: the focus state is private, and wrapping the view with `.focusScope` plus `.prefersDefaultFocus(in:)` (tried in CBTerrain on macOS) did not focus it.

Steps:
1. Show a view with `.fpvMovement(cameraMatrix:)` as the window's main content.
2. Press W without clicking.

Expected: the camera moves.
Actual: nothing happens until the view is clicked.

---

## 52: FPV is missing common 3D navigation controls

+++
status: closed
priority: low
kind: enhancement
labels: fpv
created: 2026-11-08T06:50:23Z
updated: 2026-11-08T07:02:27Z
closed: 2026-11-08T07:02:27Z
+++

FPV keyboard/mouse navigation (`fpvMovement`) supports WASD, Q/E down/up, arrow-key look and Shift for fast movement. Several controls common in 3D editors and games are missing:

- **Speed adjustment while moving:** mouse wheel (Unreal, Blender fly mode) or +/- to change the base speed. Hosts with large scenes currently need their own speed slider (e.g. CBTerrain, 10 to 2,000 m/s).
- **Slow modifier:** Ctrl or Alt for precise movement (Unreal uses Alt), the counterpart to Shift.
- **Roll:** 6DOF roll for flight/space-style navigation. Q/E are taken by altitude, so roll would need other keys (commonly Z/C).
- **Alternative up/down:** Space and C (or Ctrl), the game convention, in addition to Q/E.
- **Frame/reset:** F to frame a target and Home to reset the view, as in Unity, Unreal and Blender.
- **Hold-to-look:** look and move only while the right mouse button is held (Unity/Unreal scene views), which avoids permanent mouse capture.

Some of these overlap or conflict (Ctrl for slow vs down, Q/E for altitude vs roll), so not all can be on at once.

---

## 53: Clients have no two-way way to toggle FPV mouse look

+++
status: closed
priority: low
kind: enhancement
labels: fpv
created: 2026-11-08T06:54:36Z
updated: 2026-11-08T07:05:27Z
closed: 2026-11-08T07:05:27Z
+++

The library no longer adds a ⌘T shortcut for mouse look (removed in #44), but clients that want such a toggle have no convenient way to build one. `FPVMovementSettings.isMouseLookEnabled` is a one-way value: the client cannot observe the current state, and the toolbar capture/release state lives in private `WASDController` state.

The demos (e.g. WorldView via `showsControls`) relied on the library-provided toggle and now have no ⌘T toggle.

## Proposed fix (per Jonathan)
Expose mouse look state as a `@Binding` (or similar) so clients can wire their own shortcut, and have the demos add their own ⌘T shortcut.

---

## 54: Closure-typed @Entry environment values produce compiler warnings

+++
status: closed
priority: low
kind: bug
labels: swiftui
created: 2026-11-08T07:15:34Z
updated: 2026-11-08T15:06:28Z
closed: 2026-11-08T15:06:28Z
+++

Building Interaction3D (and every package that depends on it) emits three warnings from `GestureManager.swift`:

```
GestureManager.swift:225: Storing a closure in '@Entry var interactionDragFilter' may invalidate dependents on every update because closures may not be comparable. (from macro 'Entry')
GestureManager.swift:229: Storing a closure in '@Entry var interactionScrollFilter' may invalidate dependents on every update because closures may not be comparable. (from macro 'Entry')
GestureManager.swift:233: Storing a closure in '@Entry var interactionMagnifyFilter' may invalidate dependents on every update because closures may not be comparable. (from macro 'Entry')
```

Besides the noise in client builds (seen in CBTerrain with Xcode 27.2), the warning points at a real cost: views reading these values may be invalidated on every environment update.

---

## 55: Closure-based Bindings in CameraZoom and ToolPicker

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s, area:swiftui
created: 2026-11-08T16:30:56Z
updated: 2026-11-08T16:40:33Z
closed: 2026-11-08T16:40:33Z
+++

Two library views build `Binding { get } set: { set }` adapters, which the SwiftUI house rules treat as a performance hazard (new binding locations on every rebuild can invalidate child views):

- `Controllers/CameraZoom.swift:80` — `coordinate` maps distance to zoom coordinate.
- `Support/ToolPicker.swift:170` — `binding(for:)` per tool group.

`FPV/FPVFlightSimModifier.swift:42` (`isMouseLookEnabled`) selects between an external and a local binding in a computed property; its update behavior has not been verified.

- `2026-11-08T16:36:23Z`: Related: #67 and #68 (closures defeating SwiftUI comparison).
- `2026-11-08T16:40:33Z`: Replaced both Binding(get:set:) adapters with key-path projections: $model.activeTools[group] in ToolPicker, and a BinaryFloatingPoint[zoomCoordinate:] subscript in CameraZoom. Added zoomCoordinateSubscriptMapsAndClamps test.

---

## 56: SwiftUI view types without a View suffix

+++
status: open
priority: low
kind: task
labels: effort:m, area:swiftui
created: 2026-11-08T16:30:56Z
updated: 2026-11-08T16:36:22Z
+++

House rules require SwiftUI view types to end in `View`. About 24 do not, including public API:

Library: `RotationWidget`, `RotationWidgetCanvas`, `HoverArea`, `HorizonCue`, `FloatSlider`, `AngleSlider`, `TransformerParameterEditor`, `ParameterControl`, `ToolPickerHost`, `CameraPositionEditor`, `CameraOrientationEditor`, `ScrubbableValueField`, `AngleOfViewControl`, `ClippingRangeControl`.

Demo: `WidgetsDemo`, `TurntableDemo`, `GestureManagerDemo`, `InspectorXYRow`, `InspectorValueRow`, `WorldViewDemo`, `AnimatedConstraintDemo`, `DragDemo`, `ConstraintDemo`, `SpaceMouseDemo`.

---

## 57: Hand-rolled label/value rows instead of LabeledContent

+++
status: closed
priority: low
kind: task
labels: effort:xs, area:swiftui
created: 2026-11-08T16:30:56Z
updated: 2026-11-08T16:41:22Z
closed: 2026-11-08T16:41:22Z
+++

`FlightControlsPanelView` (`FPV/FPVFlightSimModifier.swift`) builds three rows as `HStack { Text(label); Spacer(); Text(value) }` (Movement Speed, Mouse Sensitivity, Controller Turn Speed). `ConnectedDevicesDemo` may have the same pattern. House rules call for `LabeledContent` here.

- `2026-11-08T16:41:22Z`: FlightControlsPanelView's three label/value rows now use LabeledContent. ConnectedDevicesDemo's row is an icon + title + kind header with extra lines, not a label/value pair, so it stays as is. No test: pure view refactor.

---

## 58: Fixed font sizes in instrument views

+++
status: open
priority: low
kind: task
labels: effort:s, area:swiftui, area:accessibility
created: 2026-11-08T16:30:56Z
updated: 2026-11-08T16:36:22Z
+++

13 uses of `.font(.system(size:))` bypass Dynamic Type: `SpeedometerView`, `SpeedometerDialView`, `ArtificialHorizonView`, `MapView`, `CompassView`. Canvas-drawn labels in fixed-size instruments may justify fixed sizes, but `CompassView.swift:162` and `SpeedometerDialView.swift:83,104,109` are regular view text.

---

## 59: AppKit usage and os() conditionals where SwiftUI or canImport fit

+++
status: open
priority: low
kind: task
labels: effort:s, area:platforms
created: 2026-11-08T16:31:03Z
updated: 2026-11-08T16:36:22Z
+++

- `Controllers/GestureManager.swift:90` and `Controllers/DragGestureModifier.swift` read `NSEvent.modifierFlags`; SwiftUI has `onModifierKeysChanged` (macOS 15+, availability vs deployment target not checked).
- `FPV/WASDController.swift` uses `NSEvent` monitors and `pressedMouseButtons` with no comment explaining why AppKit is required.
- AppKit imports are guarded with `#if os(macOS)` rather than `#if canImport(AppKit)`.

---

## 60: SwiftUI house-rule cleanups: spacing literals, easeInOut, previews, dead code

+++
status: open
priority: low
kind: task
labels: effort:m, area:swiftui
created: 2026-11-08T16:31:03Z
updated: 2026-11-08T16:36:22Z
+++

- Numeric padding/spacing literals in library views: `GameControllerSnapshotView` (`.padding(12)`, `spacing: 4`), `CompassView` (`.padding(2)`), `TransformerParameterEditor` (`spacing: 12`), `FPVFlightSimModifier` (`.padding(20)`, `spacing: 16/8/4`). Demos have ~25 more.
- `RotationWidget.swift:39` uses `.easeInOut(duration: 0.5)`; house style is `.smooth`.
- Only 21 of 39 view files have a `#Preview`; leaf views such as `HorizonCue`, `ScrubbableValueField`, and the camera pose editors have none.
- `PitchYawDemoView` uses `GeometryReader` and a computed `cubePanel: some View`.
- Commented-out code at `CompassView.swift:138`.

---

## 61: FlightSim map zoom buttons and RotationWidget hover buttons are unlabeled for VoiceOver

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:accessibility
created: 2026-11-08T16:34:16Z
updated: 2026-11-08T16:38:09Z
closed: 2026-11-08T16:38:09Z
+++

- `FPV/FPVFlightSimModifier.swift:155-165`: map zoom in/out buttons have only `Image(systemName:)` labels, so VoiceOver has no name for them.
- `RotationWidget/RotationWidget.swift:277` (`HoverArea`): the button label is a filled `Path` with no accessibility label. The button exists only while the pointer hovers over it, so keyboard and VoiceOver users cannot reach these actions at all.
- `RotationWidget.swift:39`: the reset rotation animation ignores Reduce Motion.

- `2026-11-08T16:36:22Z`: Related: #65 (HoverArea tuple has no field for an accessibility name).
- `2026-11-08T16:38:09Z`: Fixed: labeled map zoom buttons, VoiceOver 'View <face>' actions on RotationWidget, Reduce Motion skips the slerp. No unit test: accessibility/UI behavior is not reachable from the unit test target.

---

## 62: Elapsed-time measurements use wall-clock Date()

+++
status: closed
priority: low
kind: bug
labels: effort:s, area:swiftui
created: 2026-11-08T16:34:16Z
updated: 2026-11-08T16:41:00Z
closed: 2026-11-08T16:41:00Z
+++

Velocity and inactivity timing use `Date()` / `Date().timeIntervalSinceReferenceDate`, which jumps when the system clock changes:

- `Controllers/DragGestureModifier.swift:124`
- `Support/DraggableValueViewModifier.swift:80,108`
- `Support/NewDraggableValueViewModifier.swift:59,86`
- `FPV/GameControllerMovementController.swift:126,134,228,236`

- `2026-11-08T16:41:00Z`: Drag inactivity timing now uses ContinuousClock.Instant (monotonic) in DragGestureModifier and both DraggableValue modifiers. GameControllerMovementController.lastInputTimestamp stays a Date (it is a public 'when' timestamp, not used for elapsed time) and now uses Date.now. No unit test: the timing lives inside gesture callbacks and a wall-clock jump is not reproducible in the unit test target.

---

## 63: CityModel in WorldViewDemo is @Observable without @MainActor

+++
status: open
priority: low
kind: task
labels: effort:xs, area:swiftui
created: 2026-11-08T16:34:16Z
updated: 2026-11-08T16:36:22Z
+++

`Interaction3DDemo/Interaction3D/Demos/Old/WorldViewDemo.swift:41`: `CityModel` is `@Observable` but not `@MainActor`, unlike the other observable classes in the project.

---

## 64: Duplicate DraggableValueViewModifier and NewDraggableValueViewModifier

+++
status: open
priority: low
kind: task
labels: effort:s, area:swiftui
created: 2026-11-08T16:34:16Z
updated: 2026-11-08T16:36:22Z
+++

`Support/DraggableValueViewModifier.swift` and `Support/NewDraggableValueViewModifier.swift` contain near-duplicate drag-value modifiers. It is unclear which is current; one may be dead code.

---

## 65: HoverArea actions use an unlabeled tuple

+++
status: open
priority: low
kind: task
labels: effort:xs, area:swiftui
created: 2026-11-08T16:34:16Z
updated: 2026-11-08T16:36:22Z
+++

`RotationWidget/RotationWidget.swift:268`: `HoverArea.actions` is `[(Path, Color, () -> Void)]` and is accessed as `.0`/`.1`/`.2`. There is no field for an accessibility name.

- `2026-11-08T16:36:22Z`: Related: #61 (HoverArea buttons lack VoiceOver labels).

---

## 66: C-style String(format:) number formatting

+++
status: open
priority: low
kind: task
labels: effort:xs, area:swiftui
created: 2026-11-08T16:34:16Z
updated: 2026-11-08T16:36:22Z
+++

- `Views/SpeedometerView.swift:56`
- `Views/GameControllerSnapshotView.swift:96`
- `Interaction3DDemo/Interaction3D/Demos/SpaceMouseDemo.swift:88,174`

These format numbers with `String(format:)` instead of `FormatStyle`, so output is not localized.

---

## 67: InteractionLocationFilter still stores a closure in the environment

+++
status: closed
priority: medium
kind: bug
labels: effort:m, area:swiftui
created: 2026-11-08T16:35:40Z
updated: 2026-11-08T16:38:47Z
closed: 2026-11-08T16:38:47Z
+++

The #54 fix wrapped the filter closures in `InteractionLocationFilter` (`Controllers/GestureManager.swift`), with `==` comparing a caller-supplied `id`. Apple guidance (swiftui-specialist, environment.md, "Not a fix: Wrapping the closure in a struct") says a struct that stores a closure is not an acceptable fix for closures in custom environment keys, and that the closure should be eliminated in favor of stored data plus a method.

The `id`-based equality also means that if a client changes what the closure captures without changing `id`, SwiftUI can keep the old predicate and readers will use stale filter logic.

- `2026-11-08T16:36:22Z`: Related: #54 (introduced InteractionLocationFilter) and #55 (closure-based bindings).
- `2026-11-08T16:38:47Z`: Replaced the closure wrapper with an InteractionLocationFilter protocol (accepts(_:)); environment holds any InteractionLocationFilter, so clients store data, not closures. Breaking: interaction*Filter modifiers now take a conforming value instead of id + closure. No unit test: environment comparison/invalidation is not observable from the unit test target.

---

## 68: InteractionAxisTransforms closures defeat gesture modifier input comparison

+++
status: closed
priority: medium
kind: bug
labels: effort:m, area:camera
created: 2026-11-08T16:35:40Z
updated: 2026-11-08T16:39:43Z
closed: 2026-11-08T16:39:43Z
+++

`InteractionAxisTransforms` (`Controllers/InteractionTypes.swift`) is a struct of four `@Sendable` closures (yaw, pitch, zoom, pan). It is passed as an input to `CameraControlsModifier`, `CameraRotationModifier`, `OptionalCameraPanModifier`, `CameraZoomModifier`, and the transformers. `YawPitchDragModifier` (`Controllers/YawPitchCameraModifiers.swift`) also takes `yawDelta`/`pitchDelta` closures built fresh in `interactiveCamera(yaw:pitch:...)` and `interactiveLook`.

SwiftUI cannot compare closures, so these modifier inputs are treated as changed on every parent body evaluation, and the gesture modifier chain re-evaluates each time, including during drags when the camera binding updates every frame.

- `2026-11-08T16:36:23Z`: Related: #55 and #67.
- `2026-11-08T16:39:43Z`: InteractionAxisTransforms is now an Equatable struct of linear scales (yaw/pitch/zoom/pan) with yaw(_:)/pitch(_:)/zoom(_:)/pan(_:) methods; YawPitchDragModifier takes transforms + sign instead of closures. Breaking: custom closure transforms (nonlinear curves) are no longer expressible; all in-repo uses were linear. Test interactionAxisTransformsCompareByValue failed to compile before (not Equatable) and passes now.

---

## 69: InteractiveCameraMatrixModifier decomposes the camera matrix in init

+++
status: open
priority: low
kind: task
labels: effort:xs, area:camera
created: 2026-11-08T16:35:40Z
updated: 2026-11-08T16:36:22Z
+++

`InteractiveCameraMatrixModifier.init` (`Controllers/InteractiveCameraMatrixModifier.swift`) builds a `CameraMatrixSynchronizer` and decomposes `cameraMatrix` to seed `State(initialValue:)`. The initializer runs every time the parent body is evaluated, which during interaction is every frame, but the result is only used the first time.

---

## 70: ScrollGestureModifier uses @State plus onChange as an event channel

+++
status: open
priority: low
kind: task
labels: effort:s, area:camera
created: 2026-11-08T16:35:41Z
updated: 2026-11-08T16:36:22Z
+++

`ScrollGestureModifier` (`Controllers/GestureManager.swift`) writes each scroll delta into `@State delta`, reacts in `onChange(of: delta)`, then resets `delta = 0`. Each scroll event causes two state writes and two body evaluations of the modifier.

---

## 71: AnimatedSizeModifier hand-writes animatableData

+++
status: open
priority: low
kind: task
labels: effort:xs, area:swiftui
created: 2026-11-08T16:35:41Z
updated: 2026-11-08T16:36:22Z
+++

`AnimatedSizeModifier` (`Controllers/GestureManager.swift`) implements `animatableData` with `AnimatablePair` manually. The deployment target (macOS/iOS 26) supports the `@Animatable` macro (with `@AnimatableIgnored` for `onChange`), which Apple guidance prefers.

---
