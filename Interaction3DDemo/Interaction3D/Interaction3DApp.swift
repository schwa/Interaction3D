import DemoKit
import SwiftUI

@main
struct Interaction3DApp: App {
    static var demos: [any DemoView.Type] {
        var demos: [any DemoView.Type] = [
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
            NewTurntableDemo.self,
        ]
        #if os(macOS)
        demos.append(SpaceMouseDemo.self)
        #endif
        return demos
    }

    var body: some Scene {
        DemoPickerScene(demos: Self.demos)
        .handleDemoURL(scheme: "interaction3d")
    }
}
