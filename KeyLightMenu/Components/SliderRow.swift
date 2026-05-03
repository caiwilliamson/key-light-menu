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
  var onEditingChanged: ((Bool) -> Void)?

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .frame(width: 20)
        .foregroundStyle(.secondary)
      Slider(value: $value, in: range) { editing in
        onEditingChanged?(editing)
      }
      Text(label(value))
        .frame(width: 40, alignment: .trailing)
        .monospacedDigit()
    }
  }
}
