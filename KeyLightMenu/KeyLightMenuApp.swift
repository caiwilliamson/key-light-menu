//
//  KeyLightMenuApp.swift
//  KeyLightMenu
//
//  Created by Cai Williamson on 27/04/2026.
//

import AppKit
import SwiftUI

@main
struct KeyLightMenuApp: App {
  @State private var service = KeyLightService()
  @State private var store = PresetStore()
  @State private var sceneStore = SceneStore()
  @State private var appSettings = AppSettings()

  var body: some Scene {
    MenuBarExtra {
      MainView()
        .environment(service)
        .environment(store)
        .environment(sceneStore)
        .environment(appSettings)
        .onChange(of: appSettings.appearanceMode, initial: true) { _, mode in
          switch mode {
          case .system: NSApp.appearance = nil
          case .light: NSApp.appearance = NSAppearance(named: .aqua)
          case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
          }
        }
    } label: {
      Image(systemName: service.isOn ? "rectangle.inset.fill" : "rectangle")
    }
    .menuBarExtraStyle(.window)
  }
}
