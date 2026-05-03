//
//  SettingSliderRow.swift
//  KeyLightMenu
//

import SwiftUI

/// A settings slider row matching the LightSlider visual style.
struct SettingSliderRow: View {
  let icon: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let format: (Double) -> String
  let onCommit: () -> Void

  var body: some View {
    SliderRow(icon: icon, value: $value, range: range, label: format) { editing in
      if !editing { onCommit() }
    }
  }
}
