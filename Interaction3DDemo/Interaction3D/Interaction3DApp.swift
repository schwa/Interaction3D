import DemoKit
import SwiftUI

@main
struct Interaction3DApp: App {
    var body: some Scene {
        DemoPickerScene(demos: [
            CityDemoView.self,
            ConnectedDevicesDemo.self,
            ToolDemoView.self,
            RotationWidgetDemoView.self
        ])
        .handleDemoURL(scheme: "interaction3d")
    }
}
