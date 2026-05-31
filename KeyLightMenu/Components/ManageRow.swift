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
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ReorderChevrons(
          isFirst: isFirst,
          isLast: isLast,
          onMoveUp: onMoveUp,
          onMoveDown: onMoveDown
        )
        .padding(.trailing, 3)
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          Text(name)
          info()
        }
        Spacer()
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
