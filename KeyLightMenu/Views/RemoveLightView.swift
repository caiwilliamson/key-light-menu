//
//  RemoveLightView.swift
//  KeyLightMenu
//

import SwiftUI

struct RemoveLightView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store

  let light: KeyLight
  let index: Int
  @Binding var activePanel: Panel?

  var body: some View {
    PanelSection {
      Text("Remove \"\(light.name)\"?")
        .font(.headline)
      Text("This will remove the light and all its saved presets. You can add it again later if you want to.")
        .foregroundStyle(.secondary)
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Button("Cancel") {
          activePanel = nil
          service.selectedIndex = nil
        }
        .foregroundStyle(.secondary)
        Spacer()
        Button("Remove Light") {
          activePanel = nil
          service.remove(at: index, store: store)
        }
        .foregroundStyle(.red)
      }
    }
  }
}
