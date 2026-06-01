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
    }
    .buttonStyle(.plain)
  }
}

struct LightRowHeader<LeadingAccessory: View, TrailingActions: View>: View {
  @Environment(AppSettings.self) private var appSettings
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store
  @Environment(SyncCoordinator.self) private var sync
  let light: KeyLight
  let index: Int
  let showsPresets: Bool
  let leadingAccessory: LeadingAccessory
  let trailingActions: TrailingActions

  init(
    light: KeyLight,
    index: Int,
    showsPresets: Bool = true,
    @ViewBuilder leadingAccessory: () -> LeadingAccessory,
    @ViewBuilder trailingActions: () -> TrailingActions
  ) {
    self.light = light
    self.index = index
    self.showsPresets = showsPresets
    self.leadingAccessory = leadingAccessory()
    self.trailingActions = trailingActions()
  }

  var body: some View {
    let presets = store.presets(for: light.accessoryInfo?.serialNumber ?? "")
    let lightState = service.lights.indices.contains(index) ? service.lights[index].state : nil
    VStack(alignment: .leading, spacing: 0) {
      // Title row: leading accessory + name + indicators + trailing actions
      HStack(alignment: .center, spacing: 0) {
        leadingAccessory.padding(.trailing, 3)

        HStack(spacing: 0) {
          Text(light.name)
            .lineLimit(1)
          if light.isReachable, light.accessoryInfo?.wifiInfo != nil || light.batteryInfo != nil {
            HStack(spacing: 6) {
              if let wifi = light.accessoryInfo?.wifiInfo {
                wifiIndicator(wifi)
              }
              if let battery = light.batteryInfo {
                batteryIndicator(battery)
              }
            }
            .fixedSize()
            .padding(.leading, 12)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        trailingActions.padding(.leading, 12)
      }
      VStack(alignment: .leading, spacing: 2) {
        // Status row: disconnected/error status
        if !light.isReachable || light.actionError != nil {
          if !light.isReachable {
            Text("Disconnected")
              .font(.callout)
              .foregroundStyle(.secondary)
              .padding(.top, 1)
          } else if let err = light.actionError {
            Text(err)
              .font(.callout)
              .foregroundStyle(.red)
              .padding(.top, 1)
          }
        }
        // Preset chips row
        if showsPresets, light.isReachable, !presets.isEmpty, !sync.isOptionHeld, !sync.isReordering {
          PresetChipsRow {
            ForEach(presets) { preset in
              let active = lightState?.brightness == preset.brightness && lightState?.temperature == preset.temperature
              PresetChip(label: preset.name, isActive: active) {
                Task {
                  if appSettings.turnOnLightWithPreset, service.lights[index].state?.isOn == false {
                    await service.setOn(true, at: index)
                  }
                  await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature, at: index)
                }
              }
            }
          }
          .padding(.top, 6)
        }
      }
    }
  }

  @ViewBuilder
  private func wifiIndicator(_ wifi: WifiInfo) -> some View {
    let strength = Double(wifi.signalPercent) / 100.0
    HStack(spacing: 2) {
      if appSettings.showWifiSignalPercentage {
        Text(wifi.signalPercent > 0 ? "\(wifi.signalPercent)%" : "No Signal")
          .foregroundStyle(.secondary)
          .font(.callout)
      }
      Image(systemName: "wifi", variableValue: strength)
        .foregroundStyle(.secondary)
        .tooltip("Wi-Fi Signal Strength: \(wifi.signalPercent)%\nWi-Fi Frequency: \(wifi.frequencyGHz)\nWi-Fi Network: \(wifi.ssid)")
    }
  }

  @ViewBuilder
  private func batteryIndicator(_ battery: BatteryInfo) -> some View {
    let level = battery.level
    if battery.isPluggedIn, !battery.isCharging {
      Image(systemName: "powerplug.fill")
        .foregroundStyle(.secondary)
        .tooltip("Power Source: Power Adapter")
    } else {
      HStack(spacing: 2) {
        if appSettings.showBatteryPercentage {
          Text("\(Int(level.rounded()))%")
            .foregroundStyle(.secondary)
            .font(.callout)
        }
        Battery(level: Float(level / 100), isCharging: battery.isCharging)
          .frame(height: 11)
          .tooltip("Battery Level: \(Int(level.rounded()))%\nCharging: \(battery.isCharging ? "Yes" : "No")\nPower Source: \(battery.isPluggedIn ? "Power Adapter" : "Battery")")
      }
    }
  }
}

struct LightControlsSection: View {
  @Environment(KeyLightService.self) private var service
  @Environment(SyncCoordinator.self) private var sync

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

  var body: some View {
    let brightnessGradient = TrackGradient.brightness(for: state.temperature)
    let serial = service.lights.indices.contains(index) ? service.lights[index].serial : ""
    let isSynced = sync.isOptionHeld && sync.isIncluded(serial: serial)

    VStack(alignment: .leading, spacing: 8) {
      LightSlider(
        icon: "sun.max.fill",
        value: brightnessValue,
        range: 1 ... 100,
        label: { "\(Int($0))%" },
        gradient: brightnessGradient,
        syncKind: isSynced ? .brightness : nil,
        onDragStart: onBrightnessDragStart,
        onDragChange: onBrightnessDragChange,
        onCommit: onBrightnessCommit,
        iconTooltip: "Brightness"
      )
      LightSlider(
        icon: "thermometer.medium",
        value: temperatureValue,
        range: 143 ... 344,
        label: \.kelvinLabel,
        gradient: .temperature,
        syncKind: isSynced ? .temperature : nil,
        onDragStart: onTemperatureDragStart,
        onDragChange: onTemperatureDragChange,
        onCommit: onTemperatureCommit,
        iconTooltip: "Color Temperature"
      )
    }
    .padding(.top, 6)
  }
}
