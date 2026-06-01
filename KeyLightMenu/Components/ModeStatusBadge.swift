//
//  ModeStatusBadge.swift
//  KeyLightMenu
//

import SwiftUI

struct ModeStatusBadge: View {
  let icon: String
  let label: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .foregroundStyle(.secondary)
      Text(label)
        .font(.callout)
        .foregroundStyle(.secondary)
      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .tooltip("Exit Mode")
    }
    .transition(.scale(scale: 0.75, anchor: .trailing).combined(with: .opacity))
  }
}
