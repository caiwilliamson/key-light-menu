//
//  GlobalSettingsView.swift
//  KeyLightMenu
//

import ServiceManagement
import SwiftUI

struct GlobalSettingsView: View {
  @Environment(AppSettings.self) private var appSettings
  @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled

  var body: some View {
    @Bindable var appSettings = appSettings
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
      Divider()
      SettingToggleRow(
        label: "Turn On Lights with Scene",
        subtitle: "When a scene is applied, any lights in the scene that are currently off will be turned on.",
        isOn: $appSettings.turnOnLightsWithScene
      ) {}
      SettingToggleRow(
        label: "Turn On Light With Preset",
        subtitle: "When a preset is applied, if the light is currently off it will be turned on.",
        isOn: $appSettings.turnOnLightWithPreset
      ) {}
      Divider()
      SettingToggleRow(
        label: "Show Battery Percentage",
        isOn: $appSettings.showBatteryPercentage
      ) {}
      SettingToggleRow(
        label: "Show Wi-Fi Signal Percentage",
        isOn: $appSettings.showWifiSignalPercentage
      ) {}
    }
  }
}
