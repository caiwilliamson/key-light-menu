//
//  LightRow.swift
//  KeyLightMenu
//

import SwiftUI

struct LightRow: View {
  @Environment(KeyLightService.self) private var service
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
        HStack(spacing: 4) {
          if light.isReachable {
            if service.selectedIndex == index, !sync.isOptionHeld {
              HStack(spacing: 1) {
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
      if light.isReachable, let state = light.state {
        if service.selectedIndex == index || sync.isOptionHeld {
          controlsSection(state: state)
            .transition(.rowContent)
        }
      }
    }
    .background(Color.primary.opacity(service.selectedIndex == index && !sync.isOptionHeld ? 0.05 : 0))
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

}
