//
//  LoadingView.swift
//  KeyLightMenu
//

import SwiftUI

struct LoadingView: View {
  let label: String
  var hint: String? = nil

  var body: some View {
    VStack(spacing: 0) {
      ProgressView()
        .controlSize(.small)
      Text(label)
        .foregroundStyle(.secondary)
        .padding(.top, 12)
      if let hint {
        Text(hint)
          .font(.callout)
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
          .padding(.top, 24)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(20)
  }
}
