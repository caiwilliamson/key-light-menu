//
//  KeyLightMenuApp.swift
//  KeyLightMenu
//
//  Created by Cai Williamson on 27/04/2026.
//

import SwiftUI

@main
struct KeyLightMenuApp: App {
  @State private var service = KeyLightService()
  @State private var store = PresetStore()
  @State private var sceneStore = SceneStore()

  var body: some Scene {
    MenuBarExtra {
      MainView()
        .environment(service)
        .environment(store)
        .environment(sceneStore)
    } label: {
      Image(systemName: service.isOn ? "lightbulb.fill" : "lightbulb")
    }
    .menuBarExtraStyle(.window)
  }
}
