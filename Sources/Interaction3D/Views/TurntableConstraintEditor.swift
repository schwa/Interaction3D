import SwiftUI
import simd

public struct TurntableConstraintEditor: View {
  @Binding
  private var value: TurntableControllerConstraint

  public init(value: Binding<TurntableControllerConstraint>) {
    self._value = value
  }

  public var body: some View {
    Section {
      LabeledContent("Target") {
        VectorEditor(value: targetBinding, style: .number, semantic: .point)
      }

      LabeledContent("Radius") {
        TextField(value: radiusBinding, format: .number) {
          // This line intentionally left blank
        }
        .labelsHidden()
      }

      LabeledContent("Pitch (deg)") {
        TextField(value: pitchBinding, format: .number) {
          // This line intentionally left blank
        }
        .labelsHidden()
      }

      LabeledContent("Yaw (deg)") {
        TextField(value: yawBinding, format: .number) {
          // This line intentionally left blank
        }
        .labelsHidden()
      }

      Toggle("Aim Camera Towards Target", isOn: $value.towards)
    }

    Section("Pitch Behavior") {
      DraggableValueBehaviorEditor(behavior: $value.pitchBehavior, defaultRange: -90...90)
    }

    Section("Yaw Behavior") {
      DraggableValueBehaviorEditor(behavior: $value.yawBehavior, defaultRange: 0...360)
    }
  }

  private var targetBinding: Binding<SIMD3<Float>> {
    Binding {
      value.target
    } set: { newValue in
      value.target = newValue
    }
  }

  private var radiusBinding: Binding<Double> {
    Binding {
      Double(value.radius)
    } set: { newValue in
      value.radius = Float(newValue)
    }
  }

  private var pitchBinding: Binding<Double> {
    Binding {
      value.pitch.degrees
    } set: { newValue in
      value.pitch = .degrees(newValue)
    }
  }

  private var yawBinding: Binding<Double> {
    Binding {
      value.yaw.degrees
    } set: { newValue in
      value.yaw = .degrees(newValue)
    }
  }
}

private struct DraggableValueBehaviorEditor: View {
  @Binding
  var behavior: DraggableValueBehavior

  var defaultRange: ClosedRange<Double>

  var body: some View {
    Picker("Mode", selection: behaviorKindBinding) {
      ForEach(BehaviorKind.allCases) { item in
        Text(item.title).tag(item)
      }
    }
    .pickerStyle(.segmented)

    if behavior.range != nil {
      LabeledContent("Lower Bound") {
        TextField(value: lowerBoundBinding, format: .number) {
          // This line intentionally left blank
        }
        .labelsHidden()
      }

      LabeledContent("Upper Bound") {
        TextField(value: upperBoundBinding, format: .number) {
          // This line intentionally left blank
        }
        .labelsHidden()
      }
    }
  }

  private var behaviorKindBinding: Binding<BehaviorKind> {
    Binding {
      switch behavior {
      case .linear:
        return .linear
      case .clamping:
        return .clamping
      case .wrapping:
        return .wrapping
      }
    } set: { newValue in
      let range = behavior.range ?? newValue.defaultRange(basedOn: defaultRange)
      switch newValue {
      case .linear:
        behavior = .linear
      case .clamping:
        behavior = .clamping(range)
      case .wrapping:
        behavior = .wrapping(range)
      }
    }
  }

  private func updateRange(lower: Double? = nil, upper: Double? = nil) {
    switch behavior {
    case .linear:
      break
    case .clamping(let range):
      let newLower = lower ?? range.lowerBound
      let newUpper = upper ?? range.upperBound
      behavior = .clamping(min(newLower, newUpper)...max(newLower, newUpper))
    case .wrapping(let range):
      let newLower = lower ?? range.lowerBound
      let newUpper = upper ?? range.upperBound
      behavior = .wrapping(min(newLower, newUpper)...max(newLower, newUpper))
    }
  }

  private var lowerBoundBinding: Binding<Double> {
    Binding {
      behavior.range?.lowerBound ?? defaultRange.lowerBound
    } set: { newValue in
      updateRange(lower: newValue)
    }
  }

  private var upperBoundBinding: Binding<Double> {
    Binding {
      behavior.range?.upperBound ?? defaultRange.upperBound
    } set: { newValue in
      updateRange(upper: newValue)
    }
  }

  private enum BehaviorKind: CaseIterable, Identifiable {
    case linear
    case clamping
    case wrapping

    var id: Self { self }

    var title: String {
      switch self {
      case .linear:
        return "Linear"
      case .clamping:
        return "Clamp"
      case .wrapping:
        return "Wrap"
      }
    }

    func defaultRange(basedOn fallback: ClosedRange<Double>) -> ClosedRange<Double> {
      fallback
    }
  }
}

extension DraggableValueBehavior {
  fileprivate var range: ClosedRange<Double>? {
    switch self {
    case .linear:
      return nil
    case .clamping(let range), .wrapping(let range):
      return range
    }
  }
}

#Preview {
  @Previewable @State
  var constraint = TurntableControllerConstraint(target: SIMD3<Float>(1, 2, 3), radius: 5)

  Form {
    TurntableConstraintEditor(value: $constraint)
  }
  .padding()
}
