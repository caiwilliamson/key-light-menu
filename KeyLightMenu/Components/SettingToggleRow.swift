//
//  SettingToggleRow.swift
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
                    .foregroundStyle(.secondary)
            }
        }
    }
}
