import SwiftUI
import Interaction3D
import DemoKit

struct ToolDemoView: View {
    var body: some View {
        ToolPickerHost {
            Text("Hello world")
                .tool("Red", id: "red", modifier: RedTool())
                .tool("Green", id: "green", modifier: GreenTool())
        }
    }

}

extension ToolDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "Tool Picker",
        systemImage: "wrench.and.screwdriver",
        description: "A demo of the ToolPickerHost and ToolPickerButton views.",
        group: "Interaction3D",
        keywords: ["tool", "picker", "interaction3d"],
        color: .accentColor
    )
}

struct RedTool: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            Rectangle()
                .stroke(Color.red, lineWidth: 4)
                .frame(width: 100, height: 100)
        }
    }
}

struct GreenTool: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay {
            Rectangle()
                .stroke(Color.green, lineWidth: 4)
                .frame(width: 120, height: 120)
        }
    }
}
