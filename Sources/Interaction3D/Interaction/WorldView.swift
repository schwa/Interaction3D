import Observation
import OrderedCollections
import SwiftUI

@MainActor @Observable
public final class WorldModel {
    var controllers: OrderedSet<AnyWorldController>
    public var activeControllerID: AnyHashable?

    public init() {
        self.controllers = []
    }

    public func register<C: WorldController>(_ controller: C) {
        let entry = AnyWorldController(controller)
        controllers.updateOrInsert(entry, at: controllers.count)
        if activeControllerID == nil {
            activeControllerID = entry.id
        }
    }

    public func unregister(id: AnyHashable) {
        if let index = controllers.firstIndex(where: { $0.id == id }) {
            controllers.remove(at: index)
        }
        if activeControllerID == id {
            activeControllerID = controllers.first?.id
        }
    }
}

public struct WorldView<Content: View>: View {
    @State private var model: WorldModel
    private let content: Content

    public init(model: WorldModel = WorldModel(), @ViewBuilder content: () -> Content) {
        self._model = State(initialValue: model)
        self.content = content()
    }

    public var body: some View {
        @Bindable var bindingModel = model
        let controllerList = Array(bindingModel.controllers)

        if bindingModel.activeControllerID == nil {
            bindingModel.activeControllerID = controllerList.first?.id
        } else if let current = bindingModel.activeControllerID,
                  !controllerList.contains(where: { $0.id == current }) {
            bindingModel.activeControllerID = controllerList.first?.id
        }

        return ZStack {
            content

            if let activeID = bindingModel.activeControllerID,
               let controller = controllerList.first(where: { $0.id == activeID }) {
                controller.makeBody()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if controllerList.count > 1, let firstID = controllerList.first?.id {
                let selection = Binding<AnyHashable> {
                    bindingModel.activeControllerID ?? firstID
                } set: { newValue in
                    bindingModel.activeControllerID = newValue
                }
                ControllerPicker(selection: selection, controllers: controllerList)
                    .padding()
            }
        }
        .environment(model)
    }
}

public protocol WorldController: Identifiable where ID: Hashable {
    associatedtype Body: View
    func makeBody() -> Body

    var name: LocalizedStringKey { get }
    var systemImage: String? { get }
}

public extension WorldController {
    var name: LocalizedStringKey { LocalizedStringKey(String(describing: Self.self)) }
    var systemImage: String? { nil }
}

public extension View {
    func worldController<C: WorldController>(_ controller: C) -> some View {
        modifier(WorldControllerRegistrationModifier(controller: controller))
    }
}

private struct WorldControllerRegistrationModifier<C: WorldController>: ViewModifier {
    @Environment(WorldModel.self) private var worldModel
    let controller: C

    @State private var isRegistered = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isRegistered else { return }
                worldModel.register(controller)
                isRegistered = true
            }
            .onDisappear {
                guard isRegistered else { return }
                worldModel.unregister(id: controller.id)
                isRegistered = false
            }
    }
}

struct AnyWorldController: Hashable, Identifiable, @unchecked Sendable {
    let id: AnyHashable
    let name: LocalizedStringKey
    let systemImage: String?
    private let makeBodyClosure: () -> AnyView

    init<C: WorldController>(_ controller: C) {
        self.id = AnyHashable(controller.id)
        self.name = controller.name
        self.systemImage = controller.systemImage
        self.makeBodyClosure = {
            AnyView(controller.makeBody())
        }
    }

    func makeBody() -> AnyView {
        makeBodyClosure()
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct ControllerPicker: View {
    @Binding var selection: AnyHashable
    let controllers: [AnyWorldController]

    var body: some View {
        Picker("World Controller", selection: $selection) {
            ForEach(controllers, id: \.id) { controller in
                if let symbol = controller.systemImage {
                    Label(controller.name, systemImage: symbol)
                        .tag(controller.id)
                } else {
                    Text(controller.name)
                        .tag(controller.id)
                }
            }
        }
        .pickerStyle(.menu)
        .labelStyle(.titleAndIcon)
    }
}

/*
 Example usage:

 @State private var worldModel = WorldModel()

 WorldView(model: worldModel) {
 MyRenderer()
 }
 .worldController(KeyboardNavigationController())
 .worldController(TurntableController())

 Controllers update the model and publish any camera matrices via their own
 environments—WorldView just coordinates selection.
 */
