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
status: new
priority: low
kind: none
created: 2026-04-03T00:16:43Z
+++

The default target in InteractiveCameraMatrixModifier is hardcoded to [0,0,0]. Add a parameter to allow callers to specify a custom target point for the turntable orbit.

---

## 4: WorldView should expose turntable target parameter

+++
status: new
priority: low
kind: none
created: 2026-04-04T01:32:13Z
+++

WorldView wraps InteractiveCameraMatrixModifier but doesn't expose the turntable target (pivot point). This means the turntable always orbits around the origin (0,0,0). Users who need to orbit around a different point (e.g. the centre of a scene) have to work around this by translating their geometry instead. WorldView should accept an optional target binding and pass it through to the turntable.

---

## 5: Investigate scroll wheel zoom not working with physical scroll wheel mice

+++
status: new
priority: medium
kind: bug
created: 2026-04-09T20:24:50Z
+++

ScrollWheelModifier uses NSEvent.addLocalMonitorForEvents(.scrollWheel) to capture scroll events. Works with trackpad but reportedly doesn't work with physical scroll wheel mice. May be an issue with the momentumPhase filter:

```swift
guard event.momentumPhase.isEmpty || event.momentumPhase == .changed else {
    return
}
```

Physical scroll wheel mice may not set momentumPhase the same way as trackpads. Also the hasPreciseScrollingDeltas check determines the delta multiplier — scroll wheel mice use deltaY * 10 while trackpads use scrollingDeltaY.

Used in InteractiveCameraModifier via .onScrollWheel(delta:).

---

## 6: MagnifyGesture zoom should use absolute magnification on visionOS

+++
status: new
priority: medium
kind: enhancement
created: 2026-04-09T21:43:38Z
+++

InteractiveCameraModifier diffs MagnifyGesture magnification per-frame (zoomDelta - lastZoomDelta), giving tiny deltas even when hands move far apart. On visionOS with hand tracking, pinch-to-zoom feels like holding a distance — absolute magnification maps naturally to zoom distance. Per-frame deltas work for trackpad swiping but feel unresponsive with hand tracking. Consider using absolute magnification relative to start distance on visionOS, or at least a platform-specific multiplier.

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
status: new
priority: medium
kind: bug
created: 2026-04-12T20:36:52Z
+++

Both .inspector() and .overlay() hint text may dominate the screen on iPadOS, especially in compact width. Inspector likely takes over the full screen instead of appearing as a sidebar. The hint overlay at the bottom could also obscure too much content. Need to test on iPad and consider adaptive layouts or popovers.

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
status: new
priority: low
kind: enhancement
created: 2026-07-20T18:32:49Z
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
status: new
priority: low
kind: enhancement
created: 2026-07-20T18:32:49Z
+++

Views/WorldView.swift and the RotationWidget/debug-overlay tool modifiers have no #Preview. They need a ProjectionProtocol binding and camera plumbing, so a preview requires small fixture helpers.

---
