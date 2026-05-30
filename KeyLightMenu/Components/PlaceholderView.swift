//
//  PlaceholderView.swift
//  KeyLightMenu
//

import SwiftUI

struct PlaceholderView<Icon: View>: View {
  let label: String
  var hint: String?
  let icon: Icon

  init(label: String, hint: String? = nil, @ViewBuilder icon: () -> Icon) {
    self.label = label
    self.hint = hint
    self.icon = icon()
  }

  var body: some View {
    VStack(spacing: 12) {
      icon
      Text(label)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let hint {
        Text(hint)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(30)
  }
}

extension PlaceholderView where Icon == EmptyView {
  init(label: String, hint: String? = nil) {
    self.init(label: label, hint: hint) { EmptyView() }
  }
}
