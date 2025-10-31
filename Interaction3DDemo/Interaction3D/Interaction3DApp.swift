import DemoKit
import SwiftUI

@main
struct Interaction3DApp: App {
    var body: some Scene {
        DemoPickerScene(demos: [
            ConnectedDevicesDemo.self,
            ToolDemoView.self,
            RotationWidgetDemoView.self,
            WorldViewDemo.self,
            NewTurntableDemo.self,
            DragDemo.self
        ])
        .handleDemoURL(scheme: "interaction3d")
    }
}
