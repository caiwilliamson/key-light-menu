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
  @Binding var isCreating: Bool

  @State private var presetName = ""

  var body: some View {
    Group {
      if isCreating {
        createView
          .transition(.rowContent)
      } else {
        manageView
          .transition(.rowContent)
      }
    }
    .animation(.rowSpring, value: isCreating)
  }

  // MARK: - Manage

  private var manageView: some View {
    let serial = light.accessoryInfo?.serialNumber ?? ""
    let hostPresets = store.presets(for: serial)
    return VStack(alignment: .leading, spacing: 0) {
      if hostPresets.isEmpty {
        PanelSection {
          Text("No saved presets")
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.callout)
            .padding(.top, 30)
          Text("Press + to add one")
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.callout)
            .padding(.bottom, 30)
        }
      } else {
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
      }
    }
  }

  // MARK: - Create

  @ViewBuilder
  private var createView: some View {
    if let state = light.state {
      let serial = light.accessoryInfo?.serialNumber ?? ""
      PanelSection(spacing: 8) {
        Text("Set the sliders to your desired values, then save as a preset.")
          .font(.callout)
          .foregroundStyle(.secondary)
        LightSlider(
          icon: "sun.max.fill",
          value: Double(state.brightness),
          range: 1 ... 100,
          label: { v in "\(Int(v))%" },
          gradient: .brightness(for: state.temperature),
          onCommit: { v in Task { await service.setBrightness(Int(v), at: index) } }
        )
        LightSlider(
          icon: "thermometer.medium",
          value: Double(state.temperature),
          range: 143 ... 344,
          label: { v in "\(Int(1_000_000 / v.rounded()))K" },
          gradient: .temperature,
          onCommit: { v in Task { await service.setTemperature(Int(v), at: index) } }
        )
      }
      SectionDivider()
      PanelSection {
        HStack(spacing: 8) {
          TextField("Preset Name", text: $presetName)
            .textFieldStyle(.roundedBorder)
          Button("Save") {
            guard !presetName.isEmpty else { return }
            store.add(
              name: presetName,
              brightness: state.brightness,
              temperature: state.temperature,
              lightSerial: serial
            )
            presetName = ""
            isCreating = false
          }
          .disabled(presetName.isEmpty)
          .buttonStyle(.borderedProminent)
        }
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
