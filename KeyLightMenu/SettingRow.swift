//
//  SettingRow.swift
//  KeyLightMenu
//

import SwiftUI

/// A label + toggle row, with an optional secondary subtitle beneath.
struct SettingToggleRow: View {
    let label: String
    var subtitle: String? = nil
    var isLabelSecondary: Bool = false
    @Binding var isOn: Bool
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(label)
                    .foregroundStyle(isLabelSecondary ? Color.secondary : Color.primary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .onChange(of: isOn) { _, _ in onChange() }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

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
