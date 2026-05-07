//
//  LightRow.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct LightRow: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store

  let light: KeyLight
  let index: Int
  @Binding var activePanel: Panel?

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            Text(light.name)
              .font(.headline)
              .lineLimit(1)

            Spacer()

            panelButton(.presets, active: "slider.horizontal.3", inactive: "slider.horizontal.3", label: "Presets")
            panelButton(.settings, active: "gearshape.fill", inactive: "gearshape", label: "Settings")
            panelButton(.info, active: "info.circle.fill", inactive: "info.circle", label: "Info")

            if let state = light.state {
              Button {
                Task { await service.toggle(at: index) }
              } label: {
                Image(systemName: light.isReachable && state.isOn ? "power.circle.fill" : "power.circle")
                  .font(.title)
                  .foregroundStyle(light.isReachable && state.isOn ? Color.yellow : Color.secondary)
                  .contentTransition(.symbolEffect(.replace, options: .speed(3)))
              }
              .buttonStyle(.plain)
              .disabled(!light.isReachable)
            }
          }

          HStack(spacing: 10) {
            Text(light.isReachable ? (light.state?.isOn == true ? "On" : "Off") : "Disconnected")
              .foregroundStyle(.secondary)
            if light.isReachable {
              if let battery = light.batteryInfo {
                batteryIndicator(battery)
              }
              if let wifi = light.accessoryInfo?.wifiInfo {
                wifiIndicator(wifi)
              }
            }
          }
        }
      }

      panelContent
    }
  }

  @ViewBuilder
  private var panelContent: some View {
    let isSelected = service.selectedIndex == index
    if let panel = activePanel, isSelected {
      switch panel {
      case .info:
        if let info = light.accessoryInfo {
          InfoView(light: light, info: info, index: index).environment(service)
        } else {
          loadingView
        }
      case .settings:
        if let info = light.accessoryInfo {
          SettingsView(light: light, info: info, index: index).environment(service)
        } else {
          loadingView
        }
      case .presets:
        PresetsView(light: light, index: index)
          .environment(service)
          .environment(store)
          .fixedSize(horizontal: false, vertical: true)
      }
    } else if !isSelected || activePanel == nil {
      if light.isReachable, let state = light.state {
        controlsSection(state: state)
      } else if light.state == nil, service.isLoading, isSelected {
        loadingView
      }
    }
  }

  @ViewBuilder
  private func controlsSection(state: LightState) -> some View {
    let presets = store.presets(for: light.accessoryInfo?.serialNumber ?? "")
    let brightnessGradient = TrackGradient.brightness(for: state.temperature)
    PanelSection {
      LightSlider(
        icon: "sun.max.fill",
        value: Double(state.brightness),
        range: 1 ... 100,
        label: { "\(Int($0))%" },
        gradient: brightnessGradient
      ) { v in
        Task { await service.setBrightness(Int(v), at: index) }
      }
      LightSlider(
        icon: "thermometer.medium",
        value: Double(state.temperature),
        range: 143 ... 344,
        label: { "\(Int(1_000_000 / $0.rounded()))K" },
        gradient: .temperature
      ) { v in
        Task { await service.setTemperature(Int(v.rounded()), at: index) }
      }
      if !presets.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "slider.horizontal.3")
            .frame(width: 20)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
          HFlow(itemSpacing: 6, rowSpacing: 6) {
            ForEach(presets) { preset in
              let active = preset.brightness == state.brightness && preset.temperature == state.temperature
              PresetChip(preset: preset, isActive: active, index: index)
            }
          }
        }
      }
    }
  }

  private func panelButton(_ panel: Panel, active: String, inactive: String, label: String) -> some View {
    let isActive = service.selectedIndex == index && activePanel == panel
    return Button {
      service.selectedIndex = index
      activePanel = isActive ? nil : panel
    } label: {
      Image(systemName: isActive ? active : inactive)
        .font(.title2)
        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
    }
    .buttonStyle(.plain)
    .disabled(!light.isReachable)
    .help(label)
  }

  private var loadingView: some View {
    LoadingState(label: "Loading…")
  }

  @ViewBuilder
  private func wifiIndicator(_ wifi: WifiInfo) -> some View {
    let strength = Double(wifi.signalPercent) / 100.0
    Image(systemName: "wifi", variableValue: strength)
      .imageScale(.medium)
      .foregroundStyle(.secondary)
      .frame(height: 16)
  }

  @ViewBuilder
  private func batteryIndicator(_ battery: BatteryInfo) -> some View {
    let level = battery.level
    // Plugged in but not charging = bypass mode, battery level is meaningless
    if battery.isPluggedIn, !battery.isCharging {
      Image(systemName: "powerplug.fill")
        .imageScale(.medium)
        .foregroundStyle(.secondary)
        .frame(height: 16)
    } else {
      HStack(spacing: 4) {
        Text("\(Int(level.rounded()))%")
          .foregroundStyle(.secondary)
        Battery(level: Float(level / 100), isCharging: battery.isCharging)
          .frame(height: 11)
      }
      .frame(height: 16)
    }
  }
}

private struct PresetChip: View {
  @Environment(KeyLightService.self) private var service
  let preset: Preset
  let isActive: Bool
  let index: Int

  var body: some View {
    Button {
      Task { await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature, at: index) }
    } label: {
      Text(preset.name)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color.accentColor : Color.clear, in: Capsule())
        .overlay(Capsule().strokeBorder(isActive ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1))
        .foregroundStyle(isActive ? Color.white : Color.secondary)
    }
    .buttonStyle(.plain)
  }
}
