import Collections
import Observation
import SwiftUI

@Observable
internal class ToolPickerModel {
    struct Tool: Identifiable {
        let id: AnyHashable
        let label: AnyView
        let modifier: AnyViewModifier
    }

    var tools: OrderedDictionary<Tool.ID, Tool> = [:]
    var activeTool: Tool.ID?
}

extension ToolPickerModel {
    var activeToolModifier: AnyViewModifier {
        if let activeTool, let entry = tools[activeTool] {
            entry.modifier
        }
        else {
            AnyViewModifier()
        }
    }
}

extension ToolPickerModel.Tool {
    @MainActor
    public init(id: some Hashable, label: some View, modifier: some ViewModifier) {
        self.id = AnyHashable(id)
        self.label = AnyView(label)
        self.modifier = AnyViewModifier(modifier)
    }
}

public struct ToolPickerHost<Content: View>: View {
    private let content: Content
    @State private var model = ToolPickerModel()

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .environment(model)
            .toolbar {
                Picker(selection: $model.activeTool, label: Text("Tools")) {
                    ForEach(Array(model.tools.values)) { entry in
                        entry.label.tag(entry.id)
                    }
                }
            }
            .onChange(of: model.tools.keys, initial: true) {
                if model.activeTool == nil {
                    model.activeTool = model.tools.keys.first
                }
            }
            .modifier(model.activeToolModifier)
    }
}

struct ToolModifier: ViewModifier {
    @Environment(ToolPickerModel.self)
    var toolPickerModel

    let entry: ToolPickerModel.Tool

    func body(content: Content) -> some View {
        content
            .onChange(of: entry.id, initial: true) {
                toolPickerModel.tools[entry.id] = entry
            }
    }
}

public extension View {
    func tool(_ label: some View, id: some Hashable, modifier: some ViewModifier) -> some View {
        let entry = ToolPickerModel.Tool(id: id, label: label, modifier: modifier)
        return self.modifier(ToolModifier(entry: entry))
    }

    func tool(_ label: LocalizedStringKey, id: some Hashable, modifier: some ViewModifier) -> some View {
        let entry = ToolPickerModel.Tool(id: id, label: Text(label), modifier: modifier)
        return self.modifier(ToolModifier(entry: entry))
    }
}

struct AnyViewModifier: ViewModifier {

    var _modifier: (Content) -> AnyView

    init(_ modifier: some ViewModifier) {
        self._modifier = { content in AnyView(content.modifier(modifier)) }
    }

    func body(content: Content) -> some View {
        _modifier(content)
    }
}

extension AnyViewModifier {
    init() {
        self.init(EmptyModifier())
    }
}

extension View {
    @ViewBuilder
    func modifier(_ modifier: (some ViewModifier)?) -> some View {
        if let modifier {
            self.modifier(modifier)
        }
        else {
            self.modifier(EmptyModifier())
        }
    }
}
