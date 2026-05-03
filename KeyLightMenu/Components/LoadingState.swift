//
//  LoadingState.swift
//  KeyLightMenu
//

import SwiftUI

struct LoadingState: View {
  let label: String

  var body: some View {
    VStack(spacing: 8) {
      ProgressView()
      Text(label)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
  }
}
