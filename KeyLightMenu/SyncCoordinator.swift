//
//  SyncCoordinator.swift
//  KeyLightMenu
//

import Foundation
import Observation

@Observable
@MainActor
final class SyncCoordinator {
  var isOptionHeld = false

  // Real-time display values — updated every drag frame (not throttled)
  var syncedBrightnesses: [Double] = []
  var syncedTemperatures: [Double] = []

  // Which row is currently driving each slider type
  var brightnessSourceIndex: Int? = nil
  var temperatureSourceIndex: Int? = nil

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

  func updateBrightnessSync(fromIndex: Int, value: Double) {
    guard !startBrightnesses.isEmpty, syncedBrightnesses.count == startBrightnesses.count else { return }
    // floor matches Int($0) truncation used in the brightness label
    let delta = floor(value) - Double(startBrightnesses[fromIndex])
    for j in startBrightnesses.indices {
      syncedBrightnesses[j] = max(1, min(100, Double(startBrightnesses[j]) + delta))
    }
  }

  func updateTemperatureSync(fromIndex: Int, value: Double) {
    guard !startTemperatures.isEmpty, syncedTemperatures.count == startTemperatures.count else { return }
    // rounded matches $0.rounded() used before the Kelvin conversion in the temperature label
    let delta = value.rounded() - Double(startTemperatures[fromIndex])
    for j in startTemperatures.indices {
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
