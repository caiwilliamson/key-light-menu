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
    _minBatteryLevel = State(initialValue: Self.clampBatteryLevel(battery.energySaving.minimumBatteryLevel))
    _disableWifi = State(initialValue: battery.energySaving.disableWifi == 1)
    _adjustBrightnessEnabled = State(initialValue: battery.energySaving.adjustBrightness.enable == 1)
    _adjustBrightnessLevel = State(initialValue: battery.energySaving.adjustBrightness.brightness)
  }

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        SettingToggleRow(
          label: "Studio Mode (Bypass Battery)",
          subtitle: "Studio Mode bypasses the battery, meaning the light will only function when connected to power.",
          icon: "powerplug.fill",
          isOn: $bypass,
          onChange: send
        )
      }

      if !bypass {
        PanelSection {
          SettingToggleRow(label: "Energy Saving Mode", icon: "leaf.fill", isOn: $energySavingEnabled, onChange: send)

          if energySavingEnabled {
            HStack {
              Text("When Battery Level Falls Below")
                .foregroundStyle(.secondary)
              Spacer()
              Picker("", selection: $minBatteryLevel) {
                ForEach(stride(from: 5.0, through: 50.0, by: 5.0).map { $0 }, id: \.self) { v in
                  Text("\(Int(v))%").tag(v)
                }
              }
              .labelsHidden()
              .fixedSize()
              .onChange(of: minBatteryLevel) { _, _ in send() }
            }
            SettingToggleRow(label: "Disable Wi-Fi", isLabelSecondary: true, isOn: $disableWifi, onChange: send)
              .padding(.leading, 16)
            SettingToggleRow(label: "Adjust Brightness", isLabelSecondary: true, isOn: $adjustBrightnessEnabled, onChange: send)
              .padding(.leading, 16)
            if adjustBrightnessEnabled {
              SliderRow(
                icon: "sun.max.fill",
                value: $adjustBrightnessLevel,
                range: 1 ... 100,
                label: { "\(Int($0))%" },
                gradient: .brightness(for: service.lights[index].state?.temperature ?? 200)
              ) { editing in if !editing { send() } }
                .padding(.leading, 16)
            }
          }
        }
      }
    }
    .onChange(of: battery) { _, new in
      bypass = new.bypass == 1
      energySavingEnabled = new.energySaving.enable == 1
      minBatteryLevel = Self.clampBatteryLevel(new.energySaving.minimumBatteryLevel)
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

  private static func clampBatteryLevel(_ v: Double) -> Double {
    let clamped = max(5, min(50, v))
    return (clamped / 5).rounded() * 5
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
