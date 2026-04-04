import DemoKit
import Interaction3D
import SwiftUI

struct ToolDemoView: View {
    var body: some View {
        ToolPickerHost {
            Text("Hello world")
                .tool("Red", id: "red") { RedTool() }
                .tool("Green", id: "green") { GreenTool() }
                .tool("Off", group: .debug, id: "debug-off") { EmptyModifier() }
                .tool("Overlay", group: .debug, id: "debug-overlay") { DebugOverlayToolModifier() }
        }
    }
}

extension ToolDemoView: DemoView {
    static var metadata = DemoMetadata(
        name: "Tool Picker",
        systemImage: "wrench.and.screwdriver",
        description: "Demo of the ToolPickerHost for switching between tools.",
        group: "Widgets",
        keywords: ["tool", "picker", "toolbar"],
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
