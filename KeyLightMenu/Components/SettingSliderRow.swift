//
//  SettingSliderRow.swift
//  KeyLightMenu
//

import SwiftUI

/// A label + current-value display + slider row.
struct SettingSliderRow: View {
  let label: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let format: (Double) -> String
  let onCommit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Text(label)
          .foregroundStyle(.secondary)
        Spacer()
        Text(format(value))
          .monospacedDigit()
      }
      Slider(value: $value, in: range) { editing in
        if !editing { onCommit() }
      }
    }
  }
}
