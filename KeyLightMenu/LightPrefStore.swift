//
//  LightPrefStore.swift
//  KeyLightMenu
//

import Foundation
import Observation

/// Persists app-level per-light preferences, keyed by the light's serial number.
@Observable
@MainActor
final class LightPrefStore {
  /// Serial numbers of lights that should turn off on sleep/lock and restore on wake/unlock.
  private(set) var sleepOffSerials: Set<String> = []

  private let storageKey = "keylight.prefs.sleepOff"

  init() { load() }

  func isEnabled(for serial: String) -> Bool {
    sleepOffSerials.contains(serial)
  }

  func setEnabled(_ enabled: Bool, for serial: String) {
    if enabled { sleepOffSerials.insert(serial) }
    else { sleepOffSerials.remove(serial) }
    save()
  }

  private func save() {
    UserDefaults.standard.set(Array(sleepOffSerials), forKey: storageKey)
  }

  private func load() {
    if let arr = UserDefaults.standard.stringArray(forKey: storageKey) {
      sleepOffSerials = Set(arr)
    }
  }
}
