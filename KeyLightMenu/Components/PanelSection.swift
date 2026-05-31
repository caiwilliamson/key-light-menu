//
//  PanelSection.swift
//  KeyLightMenu
//

import SwiftUI

/// Wraps rows in a consistent vertical stack with horizontal inset.
struct PanelSection<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      content()
    }
    .padding(12)
  }
}
