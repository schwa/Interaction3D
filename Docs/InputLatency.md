# Input latency

Issue #91. Seen in TinyTorii #68: in first-person mode, the camera moved late after a key press. Main-thread frames took about 70 ms.

## Before

All of these steps ran on the main actor, each in its own task:

1. `WASDController` read `GCKeyboard` on a 16 ms timer and sent `NavigationEvent`s to an `AsyncStream`. `GameControllerMovementController` did the same on an 8 ms timer.
2. `FPVNavigator` read the stream in another task and stored the key state.
3. `FPVNavigator.runUpdates` moved the camera on an 8 ms timer.
4. The renderer drew the frame.

Each task waited for a free main thread. With 70 ms frames, a key press could wait for about three frames before the camera moved. `RTSController` and `RTSNavigator` had the same chain.

## Why not move polling off the main thread

`update(deltaTime:)` and rendering still run on the main thread. A background poll gets the key state sooner, but the camera can only use it on the next main-thread update. GameController also updates button state on its handler queue, which is the main queue by default, so a read from another thread can race.

## Now

The navigators poll key and stick state at the start of `update(deltaTime:)`:

- `FPVNavigator` creates `WASDController(pollsAutomatically: false)` and `GameControllerMovementController(pollsAutomatically: false)`, and calls `poll()` on both in each update.
- `RTSNavigator` creates `RTSController(pollsAutomatically: false)` and calls `poll()` in each update.

The input that the camera uses is never older than the update that uses it. The camera still moves only once per main-thread turn, so a slow main thread still gives a low update rate, but no more extra frames of delay.

Events that come from callbacks, not from polling, still go through the `events` stream: mouse look, scroll speed, and scroll zoom.

The controllers keep their timers by default (`pollsAutomatically: true`), so code that uses them alone and reads `events` works as before.

Edge-triggered keys (speed `+`/`-`, reset) compare against the previous `poll()`. When `update` is called less often, a press shorter than one update can be missed.

While `isPaused` is true, `update` still polls, so the stored input stays current.

If an app passes `updatesAutomatically: false` and does not call `update`, key and stick input is not read.
