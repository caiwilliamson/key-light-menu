//
//  SyncCoordinator.swift
//  KeyLightMenu
//

import Foundation
import Observation

enum SyncSliderKind { case brightness, temperature }

@Observable
@MainActor
final class SyncCoordinator {
  var isOptionHeld = false {
    didSet { if isOptionHeld { isReordering = false }; syncHoveredKind = nil }
  }

  var isReordering = false {
    didSet { if isReordering { isOptionHeld = false; reset() } }
  }

  /// Which slider kind is currently hovered across all synced rows — nil when none.
  var syncHoveredKind: SyncSliderKind?

  /// Serials explicitly excluded from sync (empty = all included)
  var excludedSerials: Set<String> = {
    let arr = UserDefaults.standard.stringArray(forKey: "keylight.sync.excludedSerials") ?? []
    return Set(arr)
  }()

  func isIncluded(serial: String) -> Bool {
    !excludedSerials.contains(serial)
  }

  func setIncluded(_ included: Bool, for serial: String) {
    if included { excludedSerials.remove(serial) } else { excludedSerials.insert(serial) }
    UserDefaults.standard.set(Array(excludedSerials), forKey: "keylight.sync.excludedSerials")
  }

  // Real-time display values — updated every drag frame (not throttled)
  var syncedBrightnesses: [Double] = []
  var syncedTemperatures: [Double] = []

  // Which row is currently driving each slider type
  var brightnessSourceIndex: Int?
  var temperatureSourceIndex: Int?

  private var startBrightnesses: [Int] = []
  private var startTemperatures: [Int] = []

  func captureBrightnessStart(lights: [KeyLight]) {
    if syncedBrightnesses.isEmpty {
      startBrightnesses = lights.map { $0.state?.brightness ?? 50 }
      syncedBrightnesses = startBrightnesses.map { Double($0) }
    } else {
      // Re-dragging before API responses have settled — use displayed values as the new baseline
      // to avoid the race condition where lights[j].state still reflects stale confirmed state
      startBrightnesses = syncedBrightnesses.map { Int($0) }
    }
  }

  func captureTemperatureStart(lights: [KeyLight]) {
    if syncedTemperatures.isEmpty {
      startTemperatures = lights.map { $0.state?.temperature ?? 200 }
      syncedTemperatures = startTemperatures.map { Double($0) }
    } else {
      startTemperatures = syncedTemperatures.map { Int($0) }
    }
  }

  func updateBrightnessSync(fromIndex: Int, value: Double, lights: [KeyLight]) {
    guard !startBrightnesses.isEmpty, syncedBrightnesses.count == startBrightnesses.count else { return }
    // floor matches Int($0) truncation used in the brightness label
    let delta = floor(value) - Double(startBrightnesses[fromIndex])
    for j in startBrightnesses.indices {
      guard isIncluded(serial: lights[j].serial) else { continue }
      syncedBrightnesses[j] = max(1, min(100, Double(startBrightnesses[j]) + delta))
    }
  }

  func updateTemperatureSync(fromIndex: Int, value: Double, lights: [KeyLight]) {
    guard !startTemperatures.isEmpty, syncedTemperatures.count == startTemperatures.count else { return }
    // rounded matches $0.rounded() used before the Kelvin conversion in the temperature label
    let delta = value.rounded() - Double(startTemperatures[fromIndex])
    for j in startTemperatures.indices {
      guard isIncluded(serial: lights[j].serial) else { continue }
      syncedTemperatures[j] = max(143, min(344, Double(startTemperatures[j]) + delta))
    }
  }

  func reset() {
    startBrightnesses = []
    startTemperatures = []
    syncedBrightnesses = []
    syncedTemperatures = []
    brightnessSourceIndex = nil
    temperatureSourceIndex = nil
  }
}
