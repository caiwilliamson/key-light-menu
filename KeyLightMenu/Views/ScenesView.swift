//
//  ScenesView.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct ScenesView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store
  @Environment(SceneStore.self) private var sceneStore

  @State private var sceneName = ""
  @State private var selectedSerials: Set<String> = []

  var body: some View {
    let reachable = service.lights.indices.filter { service.lights[$0].isReachable }
    VStack(alignment: .leading, spacing: 0) {
      PanelSection {
        VStack(alignment: .leading, spacing: 4) {
          Text("New Scene")
          Text("Select lights, adjust their settings, then save as a scene.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      SectionDivider()

      if reachable.isEmpty {
        PanelSection {
          Text("No lights available")
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.callout)
            .padding(.vertical, 8)
        }
        SectionDivider()
      } else {
        ForEach(reachable, id: \.self) { i in
          let light = service.lights[i]
          let serial = light.accessoryInfo?.serialNumber ?? "\(i)"
          SceneLightRow(
            light: light,
            index: i,
            isSelected: Binding(
              get: { selectedSerials.contains(serial) },
              set: { on in
                if on { selectedSerials.insert(serial) } else { selectedSerials.remove(serial) }
              }
            )
          )
          SectionDivider()
        }
      }

      PanelSection {
        HStack(spacing: 8) {
          TextField("Scene Name", text: $sceneName)
            .textFieldStyle(.roundedBorder)
          Button("Save") { saveScene() }
            .disabled(sceneName.trimmingCharacters(in: .whitespaces).isEmpty || selectedSerials.isEmpty)
            .buttonStyle(.borderedProminent)
        }
      }

      if sceneStore.scenes.isEmpty {
        SectionDivider()
        PanelSection {
          Text("No saved scenes")
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.callout)
            .padding(.vertical, 30)
        }
      } else {
        PanelSection {
          VStack(alignment: .leading, spacing: 4) {
            Text("Manage Scenes")
            Text("Reorder or delete your saved scenes.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        SectionDivider()
        ScrollView {
          VStack(spacing: 0) {
            ForEach(sceneStore.scenes) { scene in
              SceneManageRow(
                scene: scene,
                isFirst: scene.id == sceneStore.scenes.first?.id,
                isLast: scene.id == sceneStore.scenes.last?.id
              )
              if scene.id != sceneStore.scenes.last?.id {
                SectionDivider()
              }
            }
          }
        }
        .frame(maxHeight: 125)
      }
    }
    .animation(.rowSpring, value: selectedSerials)
  }

  private func saveScene() {
    let trimmedName = sceneName.trimmingCharacters(in: .whitespaces)
    guard !trimmedName.isEmpty else { return }
    var lights: [SceneLight] = []
    for i in service.lights.indices {
      let light = service.lights[i]
      guard let serial = light.accessoryInfo?.serialNumber,
            selectedSerials.contains(serial),
            let state = light.state else { continue }
      lights.append(SceneLight(serialNumber: serial, brightness: state.brightness, temperature: state.temperature))
    }
    guard !lights.isEmpty else { return }
    sceneStore.add(name: trimmedName, lights: lights)
    sceneName = ""
    selectedSerials = []
  }
}

// MARK: - Light Row

private struct SceneLightRow: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store

  let light: KeyLight
  let index: Int
  @Binding var isSelected: Bool

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        HStack(alignment: .center, spacing: 8) {
          Toggle("", isOn: $isSelected)
            .labelsHidden()
            .toggleStyle(.checkbox)
          Text(light.name)
            .font(.headline)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        }
      }
      if isSelected, let state = light.state {
        let serial = light.accessoryInfo?.serialNumber ?? ""
        let presets = store.presets(for: serial)
        let brightnessGradient = TrackGradient.brightness(for: state.temperature)
        VStack(alignment: .leading, spacing: 10) {
          LightSlider(
            icon: "sun.max.fill",
            value: Double(state.brightness),
            range: 1 ... 100,
            label: { "\(Int($0))%" },
            gradient: brightnessGradient,
            onCommit: { v in Task { await service.setBrightness(Int(v), at: index) } }
          )
          LightSlider(
            icon: "thermometer.medium",
            value: Double(state.temperature),
            range: 143 ... 344,
            label: { "\(Int(1_000_000 / $0.rounded()))K" },
            gradient: .temperature,
            onCommit: { v in Task { await service.setTemperature(Int(v.rounded()), at: index) } }
          )
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
            .padding(.top, 6)
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 4)
        .transition(.rowContent)
      }
    }
  }
}

// MARK: - Manage Row

private struct SceneManageRow: View {
  @Environment(SceneStore.self) private var sceneStore

  let scene: LightScene
  let isFirst: Bool
  let isLast: Bool

  var body: some View {
    PanelSection {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(scene.name)
            .foregroundStyle(.secondary)
          Text("\(scene.lights.count) light\(scene.lights.count == 1 ? "" : "s")")
            .font(.callout)
            .foregroundStyle(.tertiary)
        }
        Spacer()
        Button { sceneStore.move(scene, by: -1) } label: {
          Image(systemName: "chevron.up")
            .foregroundStyle(isFirst ? Color.secondary.opacity(0.3) : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isFirst)
        Button { sceneStore.move(scene, by: 1) } label: {
          Image(systemName: "chevron.down")
            .foregroundStyle(isLast ? Color.secondary.opacity(0.3) : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        Button { sceneStore.delete(scene) } label: {
          Image(systemName: "trash")
            .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Scene Chip

struct SceneChip: View {
  @Environment(KeyLightService.self) private var service
  let scene: LightScene

  var body: some View {
    Button {
      for sl in scene.lights {
        guard let i = service.lights.firstIndex(where: { $0.accessoryInfo?.serialNumber == sl.serialNumber }) else { continue }
        Task { await service.applyPreset(brightness: sl.brightness, temperature: sl.temperature, at: i) }
      }
    } label: {
      Text(scene.name)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.clear, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
        .foregroundStyle(Color.secondary)
        .font(.callout)
    }
    .buttonStyle(.plain)
  }
}
