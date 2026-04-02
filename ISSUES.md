## 1: InteractiveCameraMatrixModifier should compute lookAt rotation when initializing from matrix
status: new
priority: medium
kind: bug
created: 2026-04-02T23:13:03.288055+00:00

When initializeStateFromMatrix() decomposes a pure translation matrix (e.g. simd_float4x4(translation: [0, 2, 6])), it gets identity rotation because there's no rotation encoded in the matrix. But the turntable target defaults to [0,0,0], so the camera should be looking AT the origin — not straight along -Z.

The fix: when initializing, compute a rotation quaternion that looks from the camera position toward the target, rather than using the decomposed rotation from the matrix. This would make all demos that use WorldView with a simple translation matrix automatically get a good initial camera angle looking at the scene.

Currently every demo in MetalSprocketsExamples that uses [0, 2, 6] as initial camera position shows the teapot in the upper half with empty space below because the camera looks level instead of down at the origin.

---

