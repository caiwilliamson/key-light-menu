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
        label: "Turn On Lights With Scene",
        subtitle: "Turn on any lights that are off when applying a Scene.",
        isOn: $appSettings.turnOnLightsWithScene
      ) {}
      SettingToggleRow(
        label: "Turn On Light With Preset",
        subtitle: "Turn on the light if it's off when applying a Preset.",
        isOn: $appSettings.turnOnLightWithPreset
      ) {}
      Divider()
      SettingToggleRow(
        label: "Expand All Lights",
        subtitle: "Show expanded controls for all lights at once.",
        isOn: $appSettings.alwaysShowSliders
      ) {}
      SettingToggleRow(
        label: "Show Battery Percentage",
        isOn: $appSettings.showBatteryPercentage
      ) {}
      SettingToggleRow(
        label: "Show Wi-Fi Signal Percentage",
        isOn: $appSettings.showWifiSignalPercentage
      ) {}
      Divider()
      HStack {
        Text("Appearance")
        Spacer()
        Picker("", selection: $appSettings.appearanceMode) {
          ForEach(AppearanceMode.allCases, id: \.self) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }
    }
  }
}
