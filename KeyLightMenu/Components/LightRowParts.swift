//
//  LightRowParts.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct LightPowerButton: View {
  let isOn: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: isOn ? "power.circle.fill" : "power.circle")
        .font(.system(size: 20))
        .foregroundStyle(isOn ? Color.yellow : Color.secondary)
        .contentTransition(.opacity)
    }
    .buttonStyle(.plain)
  }
}

struct LightRowHeader<LeadingAccessory: View, TrailingActions: View>: View {
  let light: KeyLight
  let showsIndicators: Bool
  let leadingAccessory: LeadingAccessory
  let trailingActions: TrailingActions

  init(
    light: KeyLight,
    showsIndicators: Bool = true,
    @ViewBuilder leadingAccessory: () -> LeadingAccessory,
    @ViewBuilder trailingActions: () -> TrailingActions
  ) {
    self.light = light
    self.showsIndicators = showsIndicators
    self.leadingAccessory = leadingAccessory()
    self.trailingActions = trailingActions()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 3) {
        leadingAccessory
        Text(light.name)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        trailingActions
      }
      if showsIndicators {
        HStack(spacing: 8) {
          if light.isReachable {
            if let wifi = light.accessoryInfo?.wifiInfo {
              wifiIndicator(wifi)
            }
            if let battery = light.batteryInfo {
              batteryIndicator(battery)
            }
          } else {
            Text("Disconnected")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func wifiIndicator(_ wifi: WifiInfo) -> some View {
    let strength = Double(wifi.signalPercent) / 100.0
    Image(systemName: "wifi", variableValue: strength)
      .foregroundStyle(.secondary)
      .tooltip("Wi-Fi Network: \(wifi.ssid)\nWi-Fi Frequency: \(wifi.frequencyGHz)\nWi-Fi Signal Strength: \(wifi.signalPercent)%")
  }

  @ViewBuilder
  private func batteryIndicator(_ battery: BatteryInfo) -> some View {
    let level = battery.level
    if battery.isPluggedIn, !battery.isCharging {
      Image(systemName: "powerplug.fill")
        .foregroundStyle(.secondary)
        .tooltip("Bypass Battery")
    } else {
      HStack(spacing: 2) {
        Text("\(Int(level.rounded()))%")
          .foregroundStyle(.secondary)
          .font(.callout)
        Battery(level: Float(level / 100), isCharging: battery.isCharging)
          .frame(height: 11)
      }
    }
  }
}

struct LightControlsSection: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store

  let light: KeyLight
  let index: Int
  let state: LightState
  let brightnessValue: Double
  let temperatureValue: Double
  let onBrightnessDragStart: (() -> Void)?
  let onBrightnessDragChange: ((Double) -> Void)?
  let onBrightnessCommit: (Double) -> Void
  let onTemperatureDragStart: (() -> Void)?
  let onTemperatureDragChange: ((Double) -> Void)?
  let onTemperatureCommit: (Double) -> Void
  var showsPresets: Bool = true

  var body: some View {
    let presets = store.presets(for: light.accessoryInfo?.serialNumber ?? "")
    let brightnessGradient = TrackGradient.brightness(for: state.temperature)

    VStack(alignment: .leading, spacing: 8) {
      if showsPresets, !presets.isEmpty {
        ChipRow {
          ForEach(presets) { preset in
            let active = preset.brightness == state.brightness && preset.temperature == state.temperature
            Chip(label: preset.name, isActive: active) {
              Task { await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature, at: index) }
            }
          }
        }
        .padding(.bottom, 5)
      }
      LightSlider(
        icon: "sun.max.fill",
        value: brightnessValue,
        range: 1 ... 100,
        label: { "\(Int($0))%" },
        gradient: brightnessGradient,
        onDragStart: onBrightnessDragStart,
        onDragChange: onBrightnessDragChange,
        onCommit: onBrightnessCommit,
        iconTooltip: "Brightness"
      )
      LightSlider(
        icon: "thermometer.medium",
        value: temperatureValue,
        range: 143 ... 344,
        label: { "\(Int(1_000_000 / $0.rounded()))K" },
        gradient: .temperature,
        onDragStart: onTemperatureDragStart,
        onDragChange: onTemperatureDragChange,
        onCommit: onTemperatureCommit,
        iconTooltip: "Color Temperature"
      )
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 14)
    .padding(.top, 6)
  }
}
