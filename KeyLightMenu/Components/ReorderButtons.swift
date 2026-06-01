//
//  ReorderButtons.swift
//  KeyLightMenu
//

import SwiftUI

struct ReorderButtons: View {
  let isFirst: Bool
  let isLast: Bool
  let onMoveUp: () -> Void
  let onMoveDown: () -> Void

  private let animation = Animation.easeOut(duration: 0.12)

  var body: some View {
    VStack(spacing: 2) {
      button("chevron.up", disabled: isFirst, tooltip: "Move Up", action: onMoveUp)
      button("chevron.down", disabled: isLast, tooltip: "Move Down", action: onMoveDown)
    }
    .padding(.trailing, 5)
  }

  @ViewBuilder
  private func button(_ icon: String, disabled: Bool, tooltip: String, action: @escaping () -> Void) -> some View {
    Button { withAnimation(animation) { action() } } label: {
      Image(systemName: icon)
        .foregroundStyle(disabled ? Color.secondary.opacity(0.3) : Color.secondary)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .tooltip(tooltip)
  }
}
