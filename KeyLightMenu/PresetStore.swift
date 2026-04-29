//
//  PresetStore.swift
//  KeyLightMenu
//

import Foundation

struct Preset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var lightHost: String
    var brightness: Int
    var temperature: Int
}

@Observable @MainActor final class PresetStore {
    private(set) var presets: [Preset] = []
    private let storageKey = "keylight.presets"

    init() { load() }

    func presets(for host: String) -> [Preset] {
        presets.filter { $0.lightHost == host }
    }

    func add(name: String, brightness: Int, temperature: Int, lightHost: String) {
        presets.append(Preset(name: name, lightHost: lightHost, brightness: brightness, temperature: temperature))
        save()
    }

    func delete(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = decoded
    }
}
