## 1: InteractiveCameraMatrixModifier should compute lookAt rotation when initializing from matrix
status: new
priority: medium
kind: bug
created: 2026-04-02T23:13:03.288055+00:00

When initializeStateFromMatrix() decomposes a pure translation matrix (e.g. simd_float4x4(translation: [0, 2, 6])), it gets identity rotation because there's no rotation encoded in the matrix. But the turntable target defaults to [0,0,0], so the camera should be looking AT the origin — not straight along -Z.

The fix: when initializing, compute a rotation quaternion that looks from the camera position toward the target, rather than using the decomposed rotation from the matrix. This would make all demos that use WorldView with a simple translation matrix automatically get a good initial camera angle looking at the scene.

Currently every demo in MetalSprocketsExamples that uses [0, 2, 6] as initial camera position shows the teapot in the upper half with empty space below because the camera looks level instead of down at the origin.

---

## 2: Remove or disable debug overlay tools from WorldView
status: closed
priority: medium
kind: bug
created: 2026-04-03T00:05:57.273927+00:00
updated: 2026-04-03T00:12:10.078148+00:00
closed: 2026-04-03T00:12:10.078148+00:00

WorldView unconditionally adds 'Off' and 'Overlay' debug tools (lines 47-48 of WorldView.swift). These should either be removed, gated behind a parameter (like the interaction tools), or disabled by default so they don't appear in every app that uses WorldView.

- 2026-04-03T00:12:10.079293+00:00: Gated debug overlay tools behind .debugOverlay tool option, hidden by default

---

## 3: Make turntable target configurable in InteractiveCameraMatrixModifier
status: new
priority: low
kind: none
created: 2026-04-03T00:16:43.946212+00:00

The default target in InteractiveCameraMatrixModifier is hardcoded to [0,0,0]. Add a parameter to allow callers to specify a custom target point for the turntable orbit.

---

