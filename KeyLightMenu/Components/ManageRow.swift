//
//  ManageRow.swift
//  KeyLightMenu
//

import SwiftUI

struct ManageRow<Info: View>: View {
  let name: String
  let isFirst: Bool
  let isLast: Bool
  let onMoveUp: () -> Void
  let onMoveDown: () -> Void
  let onDelete: () -> Void
  @ViewBuilder let info: () -> Info

  var body: some View {
    PanelSection {
      HStack {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          Text(name)
          info()
        }
        Spacer()
        Button(action: onMoveUp) {
          Image(systemName: "chevron.up")
            .foregroundStyle(isFirst ? Color.secondary.opacity(0.3) : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isFirst)
        .tooltip("Move Up")
        Button(action: onMoveDown) {
          Image(systemName: "chevron.down")
            .foregroundStyle(isLast ? Color.secondary.opacity(0.3) : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        .tooltip("Move Down")
        Button(action: onDelete) {
          Image(systemName: "trash")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .tooltip("Delete")
      }
    }
  }
}
