//
//  LightRow.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct LightRow: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store
  @Environment(SyncCoordinator.self) private var sync

  let light: KeyLight
  let index: Int
  @Binding var activePanel: Panel?

  @State private var isHovered = false

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        HStack(alignment: .top, spacing: 3) {
          VStack(alignment: .leading, spacing: 2) {
            Text(light.name)
              .font(.headline)
              .lineLimit(1)
            HStack(spacing: 10) {
              Text(light.isReachable ? (light.state?.isOn == true ? "On" : "Off") : "Disconnected")
                .foregroundStyle(.secondary)
              if light.isReachable {
                if let wifi = light.accessoryInfo?.wifiInfo {
                  wifiIndicator(wifi)
                }
                if let battery = light.batteryInfo {
                  batteryIndicator(battery)
                }
              }
            }
            .font(.callout)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
          .onHover { if light.isReachable { isHovered = $0 } }
          .onTapGesture {
            guard light.isReachable, !sync.isOptionHeld else { return }
            if service.selectedIndex == index {
              service.selectedIndex = nil
              activePanel = nil
            } else {
              service.selectedIndex = index
              activePanel = nil
            }
          }
          HStack(spacing: 3) {
            if light.isReachable {
              if service.selectedIndex == index, !sync.isOptionHeld {
                Group {
                  panelButton(.presets, active: "slider.horizontal.3", inactive: "slider.horizontal.3", label: "Presets")
                  panelButton(.settings, active: "gearshape.fill", inactive: "gearshape", label: "Settings")
                  panelButton(.info, active: "info.circle.fill", inactive: "info.circle", label: "Info")
                }
                .transition(.rowContent)
              }
              if let state = light.state {
                Button {
                  Task { await service.toggle(at: index) }
                } label: {
                  Image(systemName: state.isOn ? "power.circle.fill" : "power.circle")
                    .font(.title)
                    .foregroundStyle(state.isOn ? Color.yellow : Color.secondary)
                    .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
              }
            } else if !sync.isOptionHeld {
              Button {
                service.selectedIndex = index
                activePanel = .remove
              } label: {
                Image(systemName: "trash")
                  .foregroundStyle(activePanel == .remove && service.selectedIndex == index ? Color.red : Color.secondary)
              }
              .buttonStyle(.plain)
              .transition(.rowContent)
            }
          }
          .padding(.top, -4)
        }
      }
      .background(Color.primary.opacity(isHovered && service.selectedIndex != index && !sync.isOptionHeld ? 0.05 : 0))
      if service.selectedIndex == index || sync.isOptionHeld, light.isReachable || activePanel == .remove {
        if activePanel == .remove || service.selectedIndex == index {
          panelContent
            .transition(.rowContent)
        } else if sync.isOptionHeld, light.isReachable, let state = light.state {
          controlsSection(state: state)
            .transition(.rowContent)
        }
      }
    }
  }

  @ViewBuilder
  private var panelContent: some View {
    if let panel = activePanel {
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
      case .remove:
        RemoveLightView(light: light, index: index, activePanel: $activePanel)
          .environment(service)
          .environment(store)
      }
    } else if light.isReachable, let state = light.state {
      controlsSection(state: state)
    } else if light.state == nil, service.isLoading {
      loadingView
    }
  }

  @ViewBuilder
  private func controlsSection(state: LightState) -> some View {
    let presets = store.presets(for: light.accessoryInfo?.serialNumber ?? "")
    let brightnessGradient = TrackGradient.brightness(for: state.temperature)
    let brightnessValue = sync.isOptionHeld && sync.syncedBrightnesses.indices.contains(index)
      ? sync.syncedBrightnesses[index] : Double(state.brightness)
    let temperatureValue = sync.isOptionHeld && sync.syncedTemperatures.indices.contains(index)
      ? sync.syncedTemperatures[index] : Double(state.temperature)
    VStack(alignment: .leading, spacing: 10) {
      LightSlider(
        icon: "sun.max.fill",
        value: brightnessValue,
        range: 1 ... 100,
        label: { "\(Int($0))%" },
        gradient: brightnessGradient,
        onDragStart: sync.isOptionHeld ? {
          sync.brightnessSourceIndex = index
          sync.captureBrightnessStart(lights: service.lights)
        } : nil,
        onDragChange: sync.isOptionHeld ? { v in
          sync.updateBrightnessSync(fromIndex: index, value: v)
        } : nil
      ) { v in
        Task { await service.setBrightness(Int(v), at: index) }
        if sync.isOptionHeld, sync.brightnessSourceIndex == index {
          for j in sync.syncedBrightnesses.indices where j != index {
            Task { await service.setBrightness(Int(sync.syncedBrightnesses[j].rounded()), at: j) }
          }
        }
      }
      LightSlider(
        icon: "thermometer.medium",
        value: temperatureValue,
        range: 143 ... 344,
        label: { "\(Int(1_000_000 / $0.rounded()))K" },
        gradient: .temperature,
        onDragStart: sync.isOptionHeld ? {
          sync.temperatureSourceIndex = index
          sync.captureTemperatureStart(lights: service.lights)
        } : nil,
        onDragChange: sync.isOptionHeld ? { v in
          sync.updateTemperatureSync(fromIndex: index, value: v)
        } : nil
      ) { v in
        Task { await service.setTemperature(Int(v.rounded()), at: index) }
        if sync.isOptionHeld, sync.temperatureSourceIndex == index {
          for j in sync.syncedTemperatures.indices where j != index {
            Task { await service.setTemperature(Int(sync.syncedTemperatures[j].rounded()), at: j) }
          }
        }
      }
      if !sync.isOptionHeld, !presets.isEmpty {
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
        .padding(.top, 6)
        .transition(.rowContent)
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
    .padding(.top, 4)
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
          .font(.callout)
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
        .font(.callout)
    }
    .buttonStyle(.plain)
  }
}
