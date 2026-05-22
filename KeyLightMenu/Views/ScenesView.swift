//
//  ScenesView.swift
//  KeyLightMenu
//

import SwiftUI

struct ScenesView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(SceneStore.self) private var sceneStore

  @Binding var isCreating: Bool
  @State private var sceneName = ""
  @State private var selectedSerials: Set<String> = []

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

  // MARK: - Manage View

  private var manageView: some View {
    VStack(alignment: .leading, spacing: 0) {
      if sceneStore.scenes.isEmpty {
        PanelSection {
          Text("No saved scenes")
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
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 250)
      }
    }
  }

  // MARK: - Create View

  @ViewBuilder
  private var createView: some View {
    let reachable = service.lights.indices.filter { service.lights[$0].isReachable }
    VStack(alignment: .leading, spacing: 0) {
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
    isCreating = false
  }
}

// MARK: - Light Row

private struct SceneLightRow: View {
  @Environment(KeyLightService.self) private var service

  let light: KeyLight
  let index: Int
  @Binding var isSelected: Bool

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        LightRowHeader(light: light, showsIndicators: false) {
          Toggle("", isOn: $isSelected)
            .labelsHidden()
            .toggleStyle(.checkbox)
            .padding(.trailing, 5)
        } trailingActions: {
          if let state = light.state {
            LightPowerButton(isOn: state.isOn) {
              Task { await service.toggle(at: index) }
            }
          }
        }
      }
      if isSelected, let state = light.state {
        LightControlsSection(
          light: light,
          index: index,
          state: state,
          brightnessValue: Double(state.brightness),
          temperatureValue: Double(state.temperature),
          onBrightnessDragStart: nil,
          onBrightnessDragChange: nil,
          onBrightnessCommit: { v in
            Task { await service.setBrightness(Int(v), at: index) }
          },
          onTemperatureDragStart: nil,
          onTemperatureDragChange: nil,
          onTemperatureCommit: { v in
            Task { await service.setTemperature(Int(v.rounded()), at: index) }
          }
        )
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.clear, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
        .foregroundStyle(Color.secondary)
        .font(.callout)
    }
    .buttonStyle(.plain)
  }
}
