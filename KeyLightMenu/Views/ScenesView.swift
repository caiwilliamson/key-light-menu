//
//  ScenesView.swift
//  KeyLightMenu
//

import SwiftUI

struct ScenesView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(SceneStore.self) private var sceneStore

  @Binding var isCreating: Bool
  @Binding var editingScene: LightScene?
  @State private var sceneName = ""
  @State private var selectedSerials: Set<String> = []
  @State private var lightSnapshots: [(index: Int, brightness: Int, temperature: Int)] = []

  var body: some View {
    Group {
      if isCreating {
        createView
          .onAppear {
            lightSnapshots = service.lights.indices.compactMap { i in
              guard service.lights[i].isReachable, let state = service.lights[i].state else { return nil }
              return (i, state.brightness, state.temperature)
            }
            if let scene = editingScene {
              sceneName = scene.name
              selectedSerials = Set(scene.lights.map(\.serialNumber))
              for i in service.lights.indices {
                guard service.lights[i].isReachable,
                      let serial = service.lights[i].accessoryInfo?.serialNumber,
                      let sl = scene.lights.first(where: { $0.serialNumber == serial }) else { continue }
                Task { await service.applyPreset(brightness: sl.brightness, temperature: sl.temperature, at: i) }
              }
            }
          }
          .onDisappear {
            let snaps = lightSnapshots
            lightSnapshots = []
            for snap in snaps {
              guard service.lights.indices.contains(snap.index), service.lights[snap.index].isReachable else { continue }
              Task { await service.applyPreset(brightness: snap.brightness, temperature: snap.temperature, at: snap.index) }
            }
          }
      } else {
        manageView
      }
    }
  }

  // MARK: - Manage View

  private var manageView: some View {
    VStack(alignment: .leading, spacing: 0) {
      if sceneStore.scenes.isEmpty {
        PlaceholderView(label: "No saved scenes.", hint: "Press + to create one.")
      } else {
        ScrollView {
          PanelSection {
            ForEach(sceneStore.scenes) { scene in
              SceneManageRow(
                scene: scene,
                isFirst: scene.id == sceneStore.scenes.first?.id,
                isLast: scene.id == sceneStore.scenes.last?.id,
                onEdit: { editingScene = scene; isCreating = true }
              )
              if scene.id != sceneStore.scenes.last?.id {
                Divider()
                  .transaction { $0.animation = nil }
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
    PanelSection {
      if reachable.isEmpty {
        PlaceholderView(label: "No lights connected.")
      } else {
        Text("Save settings for any combination of lights as a named Scene with quick access from the home screen.")
          .foregroundStyle(.secondary)
          .font(.callout)
        Divider()
        ForEach(reachable, id: \.self) { i in
          let light = service.lights[i]
          let serial = light.serial
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
          if i != reachable.last {
            Divider()
          }
        }
      }
      Divider()
      HStack(spacing: 8) {
        TextField("Scene Name", text: $sceneName)
          .textFieldStyle(.roundedBorder)
          .onChange(of: sceneName) { _, new in if new.count > 20 { sceneName = String(new.prefix(20)) } }
        Button("Save") { saveScene() }
          .disabled(sceneName.trimmingCharacters(in: .whitespaces).isEmpty || selectedSerials.isEmpty)
          .buttonStyle(.borderedProminent)
      }
    }
  }

  private func saveScene() {
    let trimmedName = sceneName.trimmingCharacters(in: .whitespaces)
    guard !trimmedName.isEmpty else { return }
    var sceneLights: [SceneLight] = []
    for i in service.lights.indices {
      let light = service.lights[i]
      guard let serial = light.accessoryInfo?.serialNumber,
            selectedSerials.contains(serial),
            let state = light.state else { continue }
      sceneLights.append(SceneLight(serialNumber: serial, brightness: state.brightness, temperature: state.temperature))
    }
    guard !sceneLights.isEmpty else { return }
    if var scene = editingScene {
      scene.name = trimmedName
      scene.lights = sceneLights
      sceneStore.update(scene)
      editingScene = nil
    } else {
      sceneStore.add(name: trimmedName, lights: sceneLights)
    }
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
    VStack(spacing: 12) {
      LightRowHeader(light: light, index: index, showsPresets: isSelected) {
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
      }
    }
  }
}

// MARK: - Manage Row

private struct SceneManageRow: View {
  @Environment(SceneStore.self) private var sceneStore
  @Environment(KeyLightService.self) private var service

  let scene: LightScene
  let isFirst: Bool
  let isLast: Bool
  let onEdit: () -> Void

  private var canEdit: Bool {
    scene.lights.allSatisfy { sl in
      service.lights.first { $0.serial == sl.serialNumber }?.isReachable == true
    }
  }

  var body: some View {
    ManageRow(
      name: scene.name,
      isFirst: isFirst,
      isLast: isLast,
      onMoveUp: { sceneStore.move(scene, by: -1) },
      onMoveDown: { sceneStore.move(scene, by: 1) },
      onDelete: { sceneStore.delete(scene) },
      onEdit: onEdit,
      editDisabledReason: canEdit ? nil : "Some lights in this Scene are disconnected.\nConnect all lights to edit Scene."
    ) {
      HStack(spacing: 3) {
        Image(systemName: "lightbulb.2")
        Text("\(scene.lights.count) light\(scene.lights.count == 1 ? "" : "s")")
          .font(.callout)
      }
    }
    .foregroundStyle(.secondary)
  }
}
