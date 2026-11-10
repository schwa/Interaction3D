# Controllers

Interactive camera control system. Gestures feed into a modifier that delegates to a transformer to update camera state.

```mermaid
graph LR
    Gestures["Drag, Scroll, Magnify, Pan"] --> ICM["interactiveCamera"]
    ICM --> TT["TurntableTransformer"]
    ICM --> AT["ArcballTransformer"]
    TT --> State["InteractionState"]
    AT --> State
    ICMM["interactiveCamera(cameraMatrix:)"] --> ICM
```

## Types

| Type | Role |
|------|------|
| **interactiveCamera** | View extensions that wire gestures to a transformer; `InteractiveCameraMode` picks turntable or arcball |
| **interactiveCamera(cameraMatrix:)** | Convenience form that works with a `matrix_float4x4` binding |
| **TurntableTransformer** | Fixed-axis orbit: yaw around world Y, pitch around world X, clamped |
| **ArcballTransformer** | Free rotation via virtual trackball projection |
| **InteractionState** | Camera state: rotation quaternion, distance, and target point |
| **CameraZoomModel** | `.additive` or `.multiplicative(rate:)` (log-scale) zoom, with a configurable distance range |
| **YawPitchDragModifier** | Drives yaw/pitch `Angle` bindings; backs `interactiveCamera(yaw:pitch:...)` and `interactiveLook(yaw:pitch:)` |

## Options

- **Up axis:** `TurntableTransformer(upAxis:)` orbits around any up axis (default +Y). `TurntableTransformer.yawPitch(of:upAxis:)` and `rotation(yaw:pitch:upAxis:)` convert between a rotation and angles.
- **Precision:** `interactiveCamera(rotation:distance:target:)` accepts `Float` or `Double` distance and target.
- **Pan:** pass `panEnabled: false` to any `interactiveCamera` form to disable Command-drag pan.
- **State:** `interactiveCamera(_:)` takes a `Binding<InteractionState>` directly. The `cameraMatrix:`, `rotation:distance:target:` and `yaw:pitch:distance:` forms take the same `zoom`, `distanceRange` and `panEnabled` options.
- **Look-around:** `interactiveLook(yaw:pitch:pitchRange:)` for a camera at a fixed position; dragging moves the scene with the pointer.
