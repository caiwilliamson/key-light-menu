//
//  SceneStore.swift
//  KeyLightMenu
//

import Foundation
import Observation

struct SceneLight: Codable {
  var serialNumber: String
  var brightness: Int
  var temperature: Int
}

struct LightScene: Codable, Identifiable {
  var id = UUID()
  var name: String
  var lights: [SceneLight]
}

@Observable
@MainActor
final class SceneStore {
  private(set) var scenes: [LightScene] = []
  private let storageKey = "keylight.scenes"

  init() {
    load()
  }

  func add(name: String, lights: [SceneLight]) {
    scenes.append(LightScene(name: name, lights: lights))
    save()
  }

  func delete(_ scene: LightScene) {
    scenes.removeAll { $0.id == scene.id }
    save()
  }

  func move(_ scene: LightScene, by offset: Int) {
    guard let i = scenes.firstIndex(where: { $0.id == scene.id }) else { return }
    let j = i + offset
    guard scenes.indices.contains(j) else { return }
    scenes.swapAt(i, j)
    save()
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(scenes) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([LightScene].self, from: data) else { return }
    scenes = decoded
  }
}
