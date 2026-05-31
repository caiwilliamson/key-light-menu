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
  var syncKind: SyncSliderKind?
  var iconTooltip: String?
  var onEditingChanged: ((Bool) -> Void)?

  init(
    icon: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    label: @escaping (Double) -> String,
    gradient: TrackGradient,
    syncKind: SyncSliderKind? = nil,
    iconTooltip: String? = nil,
    onEditingChanged: ((Bool) -> Void)? = nil
  ) {
    self.icon = icon
    _value = value
    self.range = range
    self.label = label
    self.gradient = gradient
    self.syncKind = syncKind
    self.iconTooltip = iconTooltip
    self.onEditingChanged = onEditingChanged
  }

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .frame(width: 16)
        .foregroundStyle(.secondary)
        .tooltip(iconTooltip)
      GradientSlider(value: $value, range: range, gradient: gradient, syncKind: syncKind, onEditingChanged: onEditingChanged)
      Text(label(value))
        .frame(width: 40, alignment: .trailing)
        .monospacedDigit()
        .font(.callout)
    }
  }
}
