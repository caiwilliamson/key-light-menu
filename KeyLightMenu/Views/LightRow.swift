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
          HStack(spacing: 6) {
            Text(light.name)
              .font(.headline)
              .lineLimit(1)

            Spacer()

            panelButton(.presets, active: "slider.horizontal.3", inactive: "slider.horizontal.3")
            panelButton(.settings, active: "gearshape.fill", inactive: "gearshape")
            panelButton(.info, active: "info.circle.fill", inactive: "info.circle")

            if let state = light.state {
              Button {
                Task { await service.toggle(at: index) }
              } label: {
                Image(systemName: light.isReachable && state.isOn ? "power.circle.fill" : "power.circle")
                  .font(.title)
                  .foregroundStyle(light.isReachable && state.isOn ? Color.yellow : Color.secondary)
                  .contentTransition(.symbolEffect(.replace))
              }
              .buttonStyle(.plain)
              .disabled(!light.isReachable)
            }
          }

          Text(light.isReachable ? (light.state?.isOn == true ? "On" : "Off") : "Disconnected")
            .foregroundStyle(.secondary)
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
    PanelSection {
      LightSlider(
        icon: "sun.max.fill",
        value: Double(state.brightness),
        range: 1 ... 100,
        label: { "\(Int($0))%" }
      ) { v in
        Task { await service.setBrightness(Int(v), at: index) }
      }
      LightSlider(
        icon: "thermometer.medium",
        value: Double(state.temperature),
        range: 143 ... 344,
        label: { "\(Int(1_000_000 / $0.rounded()))K" }
      ) { v in
        Task { await service.setTemperature(Int(v), at: index) }
      }
      if !presets.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "slider.horizontal.3")
            .frame(width: 20)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
          HFlow(itemSpacing: 6, rowSpacing: 6) {
            ForEach(presets) { preset in
              Button(preset.name) {
                Task { await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature, at: index) }
              }
              .controlSize(.small)
            }
          }
        }
      }
    }
  }

  private func panelButton(_ panel: Panel, active: String, inactive: String) -> some View {
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
  }

  private var loadingView: some View {
    LoadingState(label: "Loading…")
  }
}
