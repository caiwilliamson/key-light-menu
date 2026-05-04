//
//  PresetsView.swift
//  KeyLightMenu
//

import SwiftUI

struct PresetsView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store
  let light: KeyLight
  let index: Int

  @State private var presetName = ""

  var body: some View {
    let serial = light.accessoryInfo?.serialNumber ?? ""
    let hostPresets = store.presets(for: serial)
    return VStack(spacing: 0) {
      if let state = light.state {
        PanelSection {
          Text("New Preset")
            .frame(maxWidth: .infinity, alignment: .leading)
          LightSlider(
            icon: "sun.max.fill",
            value: Double(state.brightness),
            range: 1 ... 100,
            label: { v in "\(Int(v))%" },
            gradient: .brightness(for: state.temperature)
          ) { v in Task { await service.setBrightness(Int(v), at: index) } }

          LightSlider(
            icon: "thermometer.medium",
            value: Double(state.temperature),
            range: 143 ... 344,
            label: { v in "\(Int(1_000_000 / v.rounded()))K" },
            gradient: .temperature
          ) { v in Task { await service.setTemperature(Int(v), at: index) } }

          HStack(spacing: 8) {
            Color.clear.frame(width: 20)
            TextField("Preset Name", text: $presetName)
              .textFieldStyle(.roundedBorder)
            Button("Save Preset") {
              guard !presetName.isEmpty else { return }
              store.add(
                name: presetName,
                brightness: state.brightness,
                temperature: state.temperature,
                lightSerial: serial
              )
              presetName = ""
            }
            .disabled(presetName.isEmpty)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
          }
        }
      }

      if hostPresets.isEmpty {
        SectionDivider()
        PanelSection {
          Text("No saved presets")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
        }
      } else {
        SectionDivider()
        ScrollView {
          VStack(spacing: 0) {
            ForEach(hostPresets) { preset in
              PresetRow(
                preset: preset,
                isFirst: preset.id == hostPresets.first?.id,
                isLast: preset.id == hostPresets.last?.id
              )
              if preset.id != hostPresets.last?.id {
                SectionDivider()
              }
            }
          }
        }
        .frame(maxHeight: 310)
      }
    }
  }
}

private struct PresetRow: View {
  @Environment(PresetStore.self) private var store
  let preset: Preset
  let isFirst: Bool
  let isLast: Bool

  var body: some View {
    PanelSection {
      HStack {
        Text(preset.name)
          .foregroundStyle(.secondary)
        Spacer()
        Button { store.move(preset, by: -1) } label: {
          Image(systemName: "chevron.up")
            .foregroundStyle(isFirst ? Color.secondary.opacity(0.3) : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isFirst)
        Button { store.move(preset, by: 1) } label: {
          Image(systemName: "chevron.down")
            .foregroundStyle(isLast ? Color.secondary.opacity(0.3) : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        Button { store.delete(preset) } label: {
          Image(systemName: "trash")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      LightSlider(icon: "sun.max.fill", value: Double(preset.brightness), range: 1 ... 100, label: { "\(Int($0))%" }, gradient: .brightness(for: preset.temperature))
      LightSlider(icon: "thermometer.medium", value: Double(preset.temperature), range: 143 ... 344, label: { "\(Int(1_000_000 / $0.rounded()))K" }, gradient: .temperature)
    }
  }
}
