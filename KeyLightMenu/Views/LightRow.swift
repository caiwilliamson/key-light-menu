//
//  LightRow.swift
//  KeyLightMenu
//

import SwiftUI

struct LightRow: View {
  @Environment(KeyLightService.self) private var service
  @Environment(SyncCoordinator.self) private var sync
  @Environment(AppSettings.self) private var appSettings

  let light: KeyLight
  let index: Int
  @Binding var activePanel: Panel?

  @State private var isHovered = false

  var body: some View {
    PanelSection {
      LightRowHeader(light: light, index: index, showsIndicators: !sync.isOptionHeld) {
        if sync.isOptionHeld {
          let serial = light.accessoryInfo?.serialNumber ?? "\(light.host):\(light.port)"
          Toggle("", isOn: Binding(
            get: { sync.isIncluded(serial: serial) },
            set: { sync.setIncluded($0, for: serial) }
          ))
          .labelsHidden()
          .toggleStyle(.checkbox)
          .padding(.trailing, 5)
        }
      } trailingActions: {
        HStack(spacing: 4) {
          if light.isReachable {
          if !sync.isOptionHeld {
              Menu {
                Button {
                  service.selectedIndex = index
                  activePanel = activePanel == .settings ? nil : .settings
                } label: {
                  Label("Settings", systemImage: "gearshape")
                }
                Button {
                  service.selectedIndex = index
                  activePanel = activePanel == .presets ? nil : .presets
                } label: {
                  Label("Presets", systemImage: "slider.horizontal.3")
                }
                Button {
                  service.selectedIndex = index
                  activePanel = activePanel == .info ? nil : .info
                } label: {
                  Label("Info", systemImage: "info.circle")
                }
              } label: {
                Image(systemName: "ellipsis")
                  .foregroundStyle(Color.secondary)
              }
              .menuStyle(.borderlessButton)
              .menuIndicator(.hidden)
              .fixedSize()
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
                .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .tooltip("Remove Light")
          }
        }
      }
    }
    .contentShape(Rectangle())
    .onHover { if light.isReachable, !appSettings.alwaysShowSliders { isHovered = $0 } }
    .onChange(of: light.isReachable) { _, reachable in if !reachable { isHovered = false } }
    .onChange(of: appSettings.alwaysShowSliders) { _, expand in if expand { isHovered = false } }
    .onTapGesture {
      guard light.isReachable, !sync.isOptionHeld, !appSettings.alwaysShowSliders else { return }
      if service.selectedIndex == index {
        service.selectedIndex = nil
        activePanel = nil
      } else {
        service.selectedIndex = index
        activePanel = nil
      }
    }
    .background(Color.primary.opacity(isHovered && service.selectedIndex != index && !sync.isOptionHeld ? 0.04 : 0))
    if light.isReachable, let state = light.state {
      let serial = light.accessoryInfo?.serialNumber ?? "\(light.host):\(light.port)"
      let isSyncParticipant = sync.isOptionHeld && sync.isIncluded(serial: serial)
      if sync.isOptionHeld ? isSyncParticipant : (service.selectedIndex == index || appSettings.alwaysShowSliders) {
        controlsSection(state: state)
      }
    }
  }

  @ViewBuilder
  private func controlsSection(state: LightState) -> some View {
    let serial = light.accessoryInfo?.serialNumber ?? "\(light.host):\(light.port)"
    let isSyncParticipant = sync.isOptionHeld && sync.isIncluded(serial: serial)
    let brightnessValue = isSyncParticipant && sync.syncedBrightnesses.indices.contains(index)
      ? sync.syncedBrightnesses[index] : Double(state.brightness)
    let temperatureValue = isSyncParticipant && sync.syncedTemperatures.indices.contains(index)
      ? sync.syncedTemperatures[index] : Double(state.temperature)
    LightControlsSection(
      light: light,
      index: index,
      state: state,
      brightnessValue: brightnessValue,
      temperatureValue: temperatureValue,
      onBrightnessDragStart: isSyncParticipant ? {
        sync.brightnessSourceIndex = index
        sync.captureBrightnessStart(lights: service.lights)
      } : nil,
      onBrightnessDragChange: isSyncParticipant ? { v in
        sync.updateBrightnessSync(fromIndex: index, value: v, lights: service.lights)
      } : nil,
      onBrightnessCommit: { v in
        Task { await service.setBrightness(Int(v), at: index) }
        if isSyncParticipant, sync.brightnessSourceIndex == index {
          for j in sync.syncedBrightnesses.indices where j != index && service.lights[j].isReachable {
            let jSerial = service.lights[j].accessoryInfo?.serialNumber ?? "\(service.lights[j].host):\(service.lights[j].port)"
            if sync.isIncluded(serial: jSerial) {
              Task { await service.setBrightness(Int(sync.syncedBrightnesses[j].rounded()), at: j) }
            }
          }
        }
      },
      onTemperatureDragStart: isSyncParticipant ? {
        sync.temperatureSourceIndex = index
        sync.captureTemperatureStart(lights: service.lights)
      } : nil,
      onTemperatureDragChange: isSyncParticipant ? { v in
        sync.updateTemperatureSync(fromIndex: index, value: v, lights: service.lights)
      } : nil,
      onTemperatureCommit: { v in
        Task { await service.setTemperature(Int(v.rounded()), at: index) }
        if isSyncParticipant, sync.temperatureSourceIndex == index {
          for j in sync.syncedTemperatures.indices where j != index && service.lights[j].isReachable {
            let jSerial = service.lights[j].accessoryInfo?.serialNumber ?? "\(service.lights[j].host):\(service.lights[j].port)"
            if sync.isIncluded(serial: jSerial) {
              Task { await service.setTemperature(Int(sync.syncedTemperatures[j].rounded()), at: j) }
            }
          }
        }
      }
    )
  }
}
