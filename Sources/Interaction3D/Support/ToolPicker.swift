import Collections
import Observation
import SwiftUI

public struct ToolPickerGroup: Hashable, Equatable {
    public let id: AnyHashable
    public let label: LocalizedStringKey

    public init(_ id: some Hashable, label: LocalizedStringKey) {
        self.id = AnyHashable(id)
        self.label = label
    }

    public init(_ id: some Hashable, label: String) {
        self.init(id, label: LocalizedStringKey(label))
    }

    public init(_ id: some Hashable) {
        self.init(id, label: LocalizedStringKey(String(describing: id)))
    }

    @MainActor
    public static let `default` = Self("default", label: "Tools")
    @MainActor
    public static let interaction = Self("interaction", label: "Interaction")
    @MainActor
    public static let debug = Self("debug", label: "Debug")

    public func label(_ label: LocalizedStringKey) -> Self {
        Self(id, label: label)
    }

    public func label(_ label: String) -> Self {
        Self(id, label: label)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
@Observable
internal class ToolPickerModel {
    struct Tool: Identifiable {
        let id: AnyHashable
        let group: ToolPickerGroup
        let label: AnyView
        let modifier: () -> AnyViewModifier
        let enabled: Bool
    }

    var tools: OrderedDictionary<Tool.ID, Tool> = [:]
    var activeTools: OrderedDictionary<ToolPickerGroup, Tool.ID> = [:]
}

extension ToolPickerModel {
    var activeToolModifiers: [AnyViewModifier] {
        activeTools.compactMap { _, toolID in
            guard let tool = tools[toolID], tool.enabled else {
                return nil
            }
            return tool.modifier()
        }
    }

    @MainActor
    var activeToolModifier: ToolPickerModifierSequence {
        ToolPickerModifierSequence(modifiers: activeToolModifiers)
    }

    @MainActor
    func ensureActiveTools(for enabledGroups: OrderedDictionary<ToolPickerGroup, [Tool]>) {
        var groupsToRemove: [ToolPickerGroup] = []

        for (group, selectedID) in activeTools {
            guard let tools = enabledGroups[group], tools.contains(where: { $0.id == selectedID }) else {
                groupsToRemove.append(group)
                continue
            }
        }

        for group in groupsToRemove {
            activeTools.removeValue(forKey: group)
        }

        for (group, tools) in enabledGroups {
            guard let existingSelection = activeTools[group], tools.contains(where: { $0.id == existingSelection }) else {
                if let first = tools.first {
                    activeTools[group] = first.id
                }
                continue
            }
            // Maintain insertion order for known groups.
            if activeTools.index(forKey: group) == nil {
                activeTools[group] = existingSelection
            }
        }

        let groupsToPrune = activeTools.keys.filter { enabledGroups[$0] == nil }
        for group in groupsToPrune {
            activeTools.removeValue(forKey: group)
        }
    }
}

extension ToolPickerModel.Tool {
    @MainActor
    init(id: some Hashable, group: ToolPickerGroup, label: some View, modifier: @escaping () -> some ViewModifier, enabled: Bool) {
        self.id = AnyHashable(id)
        self.group = group
        self.label = AnyView(label)
        self.modifier = { AnyViewModifier(modifier()) }
        self.enabled = enabled
    }
}

public struct ToolPickerHost<Content: View>: View {
    private let content: Content
    @State private var model = ToolPickerModel()

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let enabledTools = currentEnabledTools()
        let groupedEnabledTools = groupEnabledTools(enabledTools)
        let enabledToolKeys = enabledTools.map { ToolRegistrationKey(id: $0.id, group: $0.group) }

        return content
            .environment(model)
            .toolbar {
                ForEach(groupedEnabledTools.keys, id: \.self) { group in
                    if let tools = groupedEnabledTools[group], tools.count > 1 {
                        Picker(selection: binding(for: group), label: Text(group.label)) {
                            ForEach(tools) { entry in
                                entry.label.tag(Optional(entry.id))
                            }
                        }
                        .accessibilityLabel(group.label)
                    }
                }
            }
            .onChange(of: enabledToolKeys, initial: true) { _, _ in
                let updatedTools = currentEnabledTools()
                let updatedGroups = groupEnabledTools(updatedTools)
                model.ensureActiveTools(for: updatedGroups)
            }
            .modifier(model.activeToolModifier)
    }

    @MainActor
    private func currentEnabledTools() -> [ToolPickerModel.Tool] {
        Array(model.tools.values.filter(\.enabled))
    }

    @MainActor
    private func groupEnabledTools(_ tools: [ToolPickerModel.Tool]) -> OrderedDictionary<ToolPickerGroup, [ToolPickerModel.Tool]> {
        tools.reduce(into: OrderedDictionary<ToolPickerGroup, [ToolPickerModel.Tool]>()) { partialResult, tool in
            partialResult[tool.group, default: []].append(tool)
        }
    }

    @MainActor
    private func binding(for group: ToolPickerGroup) -> Binding<AnyHashable?> {
        Binding {
            model.activeTools[group]
        } set: { newValue in
            if let newValue {
                model.activeTools[group] = newValue
            }
            else {
                model.activeTools.removeValue(forKey: group)
            }
        }
    }
}

private struct ToolRegistrationKey: Equatable {
    var id: AnyHashable
    var group: ToolPickerGroup
}

struct ToolPickerModifierSequence: ViewModifier {
    var modifiers: [AnyViewModifier]

    init(modifiers: [AnyViewModifier] = []) {
        self.modifiers = modifiers
    }

    func body(content: Content) -> some View {
        modifiers.reduce(AnyView(content)) { view, modifier in
            AnyView(view.modifier(modifier))
        }
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
    func tool(_ label: some View, group: ToolPickerGroup = .default, id: some Hashable, enabled: Bool = true, modifier: @escaping () -> some ViewModifier) -> some View {
        let entry = ToolPickerModel.Tool(id: id, group: group, label: label, modifier: modifier, enabled: enabled)
        return self.modifier(ToolModifier(entry: entry))
    }

    func tool(_ label: LocalizedStringKey, group: ToolPickerGroup = .default, id: some Hashable, enabled: Bool = true, modifier: @escaping () -> some ViewModifier) -> some View {
        let entry = ToolPickerModel.Tool(id: id, group: group, label: Text(label), modifier: modifier, enabled: enabled)
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
