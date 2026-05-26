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
      LightRowHeader(light: light, index: index, showsIndicators: !sync.isOptionHeld && !sync.isReordering) {
        if sync.isReordering {
          VStack(spacing: 2) {
            Button { service.move(from: index, by: -1) } label: {
              Image(systemName: "chevron.up")
                .foregroundStyle(index == 0 ? Color.secondary.opacity(0.3) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            Button { service.move(from: index, by: 1) } label: {
              Image(systemName: "chevron.down")
                .foregroundStyle(index == service.lights.count - 1 ? Color.secondary.opacity(0.3) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(index == service.lights.count - 1)
          }
          .padding(.trailing, 4)
        } else if sync.isOptionHeld {
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
          if light.isReachable, !sync.isOptionHeld, !sync.isReordering {
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
                Label("Presets", systemImage: "star")
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
          } else if !sync.isOptionHeld, !sync.isReordering {
            Menu {
              Button {
                service.selectedIndex = index
                activePanel = .remove
              } label: {
                Label("Remove Light", systemImage: "trash")
              }
            } label: {
              Image(systemName: "ellipsis")
                .foregroundStyle(Color.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
          }
          LightPowerButton(isOn: light.state?.isOn ?? false) {
            Task { await service.toggle(at: index) }
          }
          .disabled(!light.isReachable || light.state == nil)
        }
      }
    }
    .contentShape(Rectangle())
    .onHover { if light.isReachable, !appSettings.alwaysShowSliders, !sync.isReordering { isHovered = $0 } }
    .onChange(of: light.isReachable) { _, reachable in if !reachable { isHovered = false } }
    .onChange(of: appSettings.alwaysShowSliders) { _, expand in if expand { isHovered = false } }
    .onChange(of: sync.isReordering) { _, reordering in if reordering { isHovered = false } }
    .onTapGesture {
      guard light.isReachable, !sync.isOptionHeld, !sync.isReordering, !appSettings.alwaysShowSliders else { return }
      if service.selectedIndex == index {
        service.selectedIndex = nil
        activePanel = nil
      } else {
        service.selectedIndex = index
        activePanel = nil
      }
    }
    .background(Color.primary.opacity(isHovered && service.selectedIndex != index && !sync.isOptionHeld && !sync.isReordering ? 0.04 : 0))
    if light.isReachable, !sync.isReordering, let state = light.state {
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
