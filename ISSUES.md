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
labels: effort:m
created: 2026-04-12T20:36:52Z
updated: 2026-08-25T21:05:45Z
+++

Both .inspector() and .overlay() hint text may dominate the screen on iPadOS, especially in compact width. Inspector likely takes over the full screen instead of appearing as a sidebar. The hint overlay at the bottom could also obscure too much content. Need to test on iPad and consider adaptive layouts or popovers.

- `2026-08-25T21:11:58Z`: Inspected all inspector and hint-overlay call sites across the demo views. Punting: the report is speculative and does not identify a reproducing demo, iPad size class, or desired compact presentation. Can you provide a screenshot/repro for one demo and confirm whether compact width should hide hints, use a popover, or present a sheet?

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
status: open
priority: low
kind: enhancement
labels: effort:l
created: 2026-07-20T18:32:49Z
updated: 2026-08-25T21:05:45Z
+++

Support/ToolPicker.swift stores tool labels and modifiers as AnyView/AnyViewModifier (~8 uses) and reduces modifiers via nested AnyView wrapping. The house rules discourage AnyView; heterogeneous storage is a semi-legitimate use, but labels could be generic or @ViewBuilder-based. Non-trivial refactor.

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
status: open
priority: low
kind: task
labels: effort:xs
created: 2026-08-25T20:57:01Z
updated: 2026-08-25T21:05:45Z
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
