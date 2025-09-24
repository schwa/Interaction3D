import GameController

func foo(_ controller: GCController) {
    let snapshot = controller.capture()
    if let extended = snapshot.extendedGamepad {
        _ = extended.leftThumbstick.xAxis.value
    }
    if let standard = snapshot.gamepad {
        _ = standard.dpad.xAxis.value
    }
    if let micro = snapshot.microGamepad {
        _ = micro.dpad.xAxis.value
    }
}
