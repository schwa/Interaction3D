import DemoKit
import SwiftUI

@main
struct Interaction3DApp: App {
    var body: some Scene {
        DemoPickerScene(demos: [
            ConnectedDevicesDemo.self,
            ToolDemoView.self,
            WorldViewDemo.self,
            PitchYawDemoView.self,
            DragDemo.self,
            ConstraintDemo.self,
            AnimatedConstraintDemo.self,
            WidgetsDemo.self,
            TurntableDemo.self,
            NewGestureManagerDemo.self,
            NewTurntableDemo.self
        ])
        .handleDemoURL(scheme: "interaction3d")
    }
}
