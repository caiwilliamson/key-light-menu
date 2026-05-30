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
  @State private var sendError: String?

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
    let isPluggedIn = service.lights[index].batteryInfo?.isPluggedIn ?? true
    VStack(spacing: 0) {
      PanelSection {
        SettingToggleRow(
          label: "Bypass Battery",
          subtitle: "Bypass the battery so the light only works when connected to power.",
          isOn: $bypass,
          onChange: send
        )
        .disabled(!isPluggedIn)
      }

      if !bypass {
        SectionDivider()

        PanelSection {
          SettingToggleRow(label: "Energy Saving Mode", isOn: $energySavingEnabled, onChange: send)

          if energySavingEnabled {
            HStack {
              Text("When Battery Level Falls Below")
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
            SettingToggleRow(label: "Disable Wi-Fi", isOn: $disableWifi, onChange: send)
              .padding(.leading, 16)
            SettingToggleRow(label: "Adjust Brightness", isOn: $adjustBrightnessEnabled, onChange: send)
              .padding(.leading, 16)
            if adjustBrightnessEnabled {
              SliderRow(
                icon: "sun.max.fill",
                value: $adjustBrightnessLevel,
                range: 1 ... 100,
                label: { "\(Int($0))%" },
                gradient: .brightness(for: service.lights[index].state?.temperature ?? 200),
                iconTooltip: "Brightness"
              ) { editing in if !editing { send() } }
                .padding(.leading, 16)
            }
          }
        }
      }
      if let err = sendError {
        SectionDivider()
        PanelSection {
          Text(err).font(.callout).foregroundStyle(.red)
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
    guard updated != battery else { return }
    sendTask?.cancel()
    sendTask = Task {
      do {
        try await service.setBatterySettings(updated, at: index)
        sendError = nil
      } catch {
        sendError = "Couldn't save — try again"
      }
    }
  }
}
