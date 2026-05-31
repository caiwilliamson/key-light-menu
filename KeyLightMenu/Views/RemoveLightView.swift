//
//  RemoveLightView.swift
//  KeyLightMenu
//

import SwiftUI

struct RemoveLightView: View {
  @Environment(KeyLightService.self) private var service

  let light: KeyLight
  let index: Int
  @Binding var activePanel: Panel?

  var body: some View {
    PanelSection {
      Text("Remove \"\(light.name)\"?")
        .font(.headline)
      Text("This will remove it from the list. It will reappear automatically if it comes back online.")
        .foregroundStyle(.secondary)
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
      Divider()
      HStack {
        Button("Cancel") {
          activePanel = nil
          service.selectedIndex = nil
        }
        .foregroundStyle(.secondary)
        Spacer()
        Button("Remove Light") {
          activePanel = nil
          service.remove(at: index)
        }
        .foregroundStyle(.red)
      }
    }
  }
}
