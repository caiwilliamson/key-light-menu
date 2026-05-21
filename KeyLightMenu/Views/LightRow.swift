//
//  LightRow.swift
//  KeyLightMenu
//

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
      LightRowHeader(light: light, showsIndicators: !sync.isOptionHeld) {
        EmptyView()
      } trailingActions: {
        HStack(spacing: 2) {
          if light.isReachable {
            if service.selectedIndex == index, !sync.isOptionHeld {
              HStack(spacing: 0) {
                panelButton(.presets, active: "slider.horizontal.3", inactive: "slider.horizontal.3", label: "Presets")
                panelButton(.settings, active: "gearshape.fill", inactive: "gearshape", label: "Settings")
                panelButton(.info, active: "info.circle.fill", inactive: "info.circle", label: "Info")
              }
              .transition(.rowContent)
            }
            if let state = light.state {
              LightPowerButton(isOn: state.isOn) {
                Task { await service.toggle(at: index) }
              }
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
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 12)
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
    .background(Color.primary.opacity(service.selectedIndex == index && !sync.isOptionHeld ? 0.05 : 0))
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
    let brightnessValue = sync.isOptionHeld && sync.syncedBrightnesses.indices.contains(index)
      ? sync.syncedBrightnesses[index] : Double(state.brightness)
    let temperatureValue = sync.isOptionHeld && sync.syncedTemperatures.indices.contains(index)
      ? sync.syncedTemperatures[index] : Double(state.temperature)
    LightControlsSection(
      light: light,
      index: index,
      state: state,
      brightnessValue: brightnessValue,
      temperatureValue: temperatureValue,
      onBrightnessDragStart: sync.isOptionHeld ? {
        sync.brightnessSourceIndex = index
        sync.captureBrightnessStart(lights: service.lights)
      } : nil,
      onBrightnessDragChange: sync.isOptionHeld ? { v in
        sync.updateBrightnessSync(fromIndex: index, value: v)
      } : nil,
      onBrightnessCommit: { v in
        Task { await service.setBrightness(Int(v), at: index) }
        if sync.isOptionHeld, sync.brightnessSourceIndex == index {
          for j in sync.syncedBrightnesses.indices where j != index {
            Task { await service.setBrightness(Int(sync.syncedBrightnesses[j].rounded()), at: j) }
          }
        }
      },
      onTemperatureDragStart: sync.isOptionHeld ? {
        sync.temperatureSourceIndex = index
        sync.captureTemperatureStart(lights: service.lights)
      } : nil,
      onTemperatureDragChange: sync.isOptionHeld ? { v in
        sync.updateTemperatureSync(fromIndex: index, value: v)
      } : nil,
      onTemperatureCommit: { v in
        Task { await service.setTemperature(Int(v.rounded()), at: index) }
        if sync.isOptionHeld, sync.temperatureSourceIndex == index {
          for j in sync.syncedTemperatures.indices where j != index {
            Task { await service.setTemperature(Int(sync.syncedTemperatures[j].rounded()), at: j) }
          }
        }
      }
    )
  }

  private func panelButton(_ panel: Panel, active: String, inactive: String, label: String) -> some View {
    let isActive = service.selectedIndex == index && activePanel == panel
    return Button {
      service.selectedIndex = index
      activePanel = isActive ? nil : panel
    } label: {
      Image(systemName: isActive ? active : inactive)
        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        .font(.system(size: 16))
    }
    .buttonStyle(.plain)
    .disabled(!light.isReachable)
    .help(label)
  }

  private var loadingView: some View {
    LoadingState(label: "Loading…")
  }
}
