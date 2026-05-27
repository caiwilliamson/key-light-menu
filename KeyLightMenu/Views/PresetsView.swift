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
  @State private var snapshot: (brightness: Int, temperature: Int)?

  var body: some View {
    Group {
      if isCreating {
        createView
          .onAppear {
            if let state = light.state {
              snapshot = (state.brightness, state.temperature)
            }
          }
          .onDisappear {
            guard let snap = snapshot else { return }
            snapshot = nil
            guard service.lights.indices.contains(index), service.lights[index].isReachable else { return }
            Task {
              await service.setBrightness(snap.brightness, at: index)
              await service.setTemperature(snap.temperature, at: index)
            }
          }
      } else {
        manageView
      }
    }
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
      VStack(alignment: .leading, spacing: 0) {
        PanelSection {
          Text("Set the sliders to your desired values, then save as a preset.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        PanelSection {
          LightRowHeader(light: light, index: index, showsPresets: false) {
            EmptyView()
          } trailingActions: {
            LightPowerButton(isOn: state.isOn) {
              Task { await service.toggle(at: index) }
            }
          }
        }
        LightControlsSection(
          light: light,
          index: index,
          state: state,
          brightnessValue: Double(state.brightness),
          temperatureValue: Double(state.temperature),
          onBrightnessDragStart: nil,
          onBrightnessDragChange: nil,
          onBrightnessCommit: { v in Task { await service.setBrightness(Int(v), at: index) } },
          onTemperatureDragStart: nil,
          onTemperatureDragChange: nil,
          onTemperatureCommit: { v in Task { await service.setTemperature(Int(v), at: index) } }
        )
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
}

private struct PresetRow: View {
  @Environment(PresetStore.self) private var store
  let preset: Preset
  let isFirst: Bool
  let isLast: Bool

  var body: some View {
    ManageRow(
      name: preset.name,
      isFirst: isFirst,
      isLast: isLast,
      onMoveUp: { store.move(preset, by: -1) },
      onMoveDown: { store.move(preset, by: 1) },
      onDelete: { store.delete(preset) }
    ) {
      HStack(spacing: 4) {
        Image(systemName: "sun.max.fill")
          .tooltip("Brightness")
        Text("\(preset.brightness)%")
          .font(.callout)
        Image(systemName: "thermometer.medium")
          .padding(.leading, 4)
          .tooltip("Color Temperature")
        Text("\(Int(1_000_000 / Double(preset.temperature).rounded()))K")
          .font(.callout)
      }
      .foregroundStyle(.secondary)
    }
  }
}
