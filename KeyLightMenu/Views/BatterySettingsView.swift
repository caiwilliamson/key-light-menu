//
//  BatterySettingsView.swift
//  KeyLightMenu
//

import SwiftUI

struct BatterySettingsView: View {
  @Environment(KeyLightService.self) private var service
  var battery: BatteryConfig
  let index: Int

  @State private var bypass: Bool
  @State private var energySavingEnabled: Bool
  @State private var minBatteryLevel: Double
  @State private var disableWifi: Bool
  @State private var adjustBrightnessEnabled: Bool
  @State private var adjustBrightnessLevel: Double
  @State private var sendTask: Task<Void, Never>?

  init(battery: BatteryConfig, index: Int) {
    self.battery = battery
    self.index = index
    _bypass = State(initialValue: battery.bypass == 1)
    _energySavingEnabled = State(initialValue: battery.energySaving.enable == 1)
    _minBatteryLevel = State(initialValue: battery.energySaving.minimumBatteryLevel)
    _disableWifi = State(initialValue: battery.energySaving.disableWifi == 1)
    _adjustBrightnessEnabled = State(initialValue: battery.energySaving.adjustBrightness.enable == 1)
    _adjustBrightnessLevel = State(initialValue: battery.energySaving.adjustBrightness.brightness)
  }

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        SettingToggleRow(
          label: "Studio Mode (Bypass Battery)",
          subtitle: bypass ? "Only works when plugged in" : "Uses battery when unplugged",
          isOn: $bypass,
          onChange: send
        )
      }

      if !bypass {
        PanelSection {
          SettingToggleRow(label: "Energy Saving Mode", isOn: $energySavingEnabled, onChange: send)

          if energySavingEnabled {
            Text("When Battery Level Falls Below")
              .foregroundStyle(.secondary)
            SettingSliderRow(
              icon: "battery.25",
              value: $minBatteryLevel,
              range: 1 ... 100,
              format: { "\(Int($0))%" },
              onCommit: send
            )
            SettingToggleRow(label: "Disable Wi-Fi", isLabelSecondary: true, isOn: $disableWifi, onChange: send)
              .padding(.leading, 16)
            SettingToggleRow(label: "Adjust Brightness", isLabelSecondary: true, isOn: $adjustBrightnessEnabled, onChange: send)
              .padding(.leading, 16)
            if adjustBrightnessEnabled {
              SettingSliderRow(
                icon: "sun.max.fill",
                value: $adjustBrightnessLevel,
                range: 1 ... 100,
                format: { "\(Int($0))%" },
                onCommit: send
              )
              .padding(.leading, 16)
            }
          }
        }
      }
    }
    .onChange(of: battery) { _, new in
      bypass = new.bypass == 1
      energySavingEnabled = new.energySaving.enable == 1
      minBatteryLevel = new.energySaving.minimumBatteryLevel
      disableWifi = new.energySaving.disableWifi == 1
      adjustBrightnessEnabled = new.energySaving.adjustBrightness.enable == 1
      adjustBrightnessLevel = new.energySaving.adjustBrightness.brightness
    }
  }

  private func buildConfig() -> BatteryConfig {
    BatteryConfig(
      energySaving: EnergySavingConfig(
        enable: energySavingEnabled ? 1 : 0,
        minimumBatteryLevel: minBatteryLevel,
        disableWifi: disableWifi ? 1 : 0,
        adjustBrightness: AdjustBrightnessConfig(
          enable: adjustBrightnessEnabled ? 1 : 0,
          brightness: adjustBrightnessLevel
        )
      ),
      bypass: bypass ? 1 : 0
    )
  }

  private func send() {
    let updated = buildConfig()
    // Don't send if the config already matches the server state (breaks the echo cycle)
    guard updated != battery else { return }
    // Cancel any in-flight request so interleaved responses can't ping-pong the value
    sendTask?.cancel()
    sendTask = Task { await service.setBatterySettings(updated, at: index) }
  }
}
