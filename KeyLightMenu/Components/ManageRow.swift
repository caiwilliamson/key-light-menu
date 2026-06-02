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
  let onEdit: () -> Void
  var editDisabledReason: String? = nil
  @ViewBuilder let info: () -> Info

  var body: some View {
    HStack(spacing: 0) {
      ReorderButtons(
        isFirst: isFirst,
        isLast: isLast,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown
      )
      .padding(.trailing, 3)
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        HStack(spacing: 12) {
          Text(name)
            .lineLimit(1)
            .truncationMode(.tail)
          info()
        }
        Spacer()
        Button(action: onEdit) {
          Image(systemName: "square.and.pencil")
            .foregroundStyle(editDisabledReason == nil ? .secondary : Color.secondary.opacity(0.3))
        }
        .buttonStyle(.plain)
        .disabled(editDisabledReason != nil)
        .tooltip(editDisabledReason ?? "Edit")
        .padding(.trailing, 8)
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
