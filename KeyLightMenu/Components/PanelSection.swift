//
//  PanelSection.swift
//  KeyLightMenu
//

import SwiftUI

/// Wraps rows in a consistent vertical stack with horizontal inset.
struct PanelSection<Content: View>: View {
  var spacing: CGFloat? = nil
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: spacing ?? 10) {
      content()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
  }
}
