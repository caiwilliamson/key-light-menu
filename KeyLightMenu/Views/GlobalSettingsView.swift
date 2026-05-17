//
//  GlobalSettingsView.swift
//  KeyLightMenu
//

import ServiceManagement
import SwiftUI

struct GlobalSettingsView: View {
  @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled

  var body: some View {
    PanelSection {
      SettingToggleRow(label: "Start at Login", isOn: $loginItemEnabled) {
        do {
          if loginItemEnabled {
            try SMAppService.mainApp.register()
          } else {
            try SMAppService.mainApp.unregister()
          }
        } catch {
          loginItemEnabled = !loginItemEnabled
        }
      }
    }
  }
}
