//
//  SliderRow.swift
//  KeyLightMenu
//

import SwiftUI

/// Shared visual layout for all light sliders: icon — slider — value label.
struct SliderRow: View {
  let icon: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let label: (Double) -> String
  let gradient: TrackGradient
  var isActive: Bool = true
  var onEditingChanged: ((Bool) -> Void)?

  init(
    icon: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    label: @escaping (Double) -> String,
    gradient: TrackGradient,
    isActive: Bool = true,
    onEditingChanged: ((Bool) -> Void)? = nil
  ) {
    self.icon = icon
    _value = value
    self.range = range
    self.label = label
    self.gradient = gradient
    self.isActive = isActive
    self.onEditingChanged = onEditingChanged
  }

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .frame(width: 16)
        .foregroundStyle(.secondary)
      GradientSlider(value: $value, range: range, gradient: gradient, isActive: isActive, onEditingChanged: onEditingChanged)
      Text(label(value))
        .frame(width: 40, alignment: .trailing)
        .monospacedDigit()
        .font(.callout)
    }
  }
}
