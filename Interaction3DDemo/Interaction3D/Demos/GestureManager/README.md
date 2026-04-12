# Gesture Manager

⚠️ **WIP / EXPERIMENTAL**

Composable gesture manager prototype. Uses ViewModifier chaining — no AnyView type erasure. Transformers handle the math, modifiers handle the plumbing.

## Known Issues

- No momentum/animation on drag release
- Modifier key exclusivity is runtime checks, not SwiftUI gesture composition
- Modifier state is captured at drag start and locked for the entire drag — toggling modifiers mid-drag won't switch gesture. May want opt-in "live" modifier checking as an alternative.

## TODO

- `onStart` callback for drag modifiers — needed for hit-test-dependent behavior. E.g. drag on background orbits around origin, drag starting on an object orbits around that object. Same gesture & transform, different parameter based on start location. Proposed API: `.dragGesture([], onStart: { startPoint in target = hitTest(startPoint) }, transformer: ..., writes: $value)`
