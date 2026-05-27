//
//  ReorderChevrons.swift
//  KeyLightMenu
//

import SwiftUI

struct ReorderChevrons: View {
  let isFirst: Bool
  let isLast: Bool
  let onMoveUp: () -> Void
  let onMoveDown: () -> Void

  var body: some View {
    VStack(spacing: 2) {
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
    }
    .padding(.trailing, 5)
  }
}
