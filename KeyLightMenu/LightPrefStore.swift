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
  /// Serial numbers of lights that should turn off on sleep/lock.
  private(set) var sleepOffSerials: Set<String> = []
  /// Serial numbers of lights that should be restored (turned back on) after wake/unlock.
  private(set) var restoreSerials: Set<String> = []

  private let sleepOffKey = "keylight.prefs.sleepOff"
  private let restoreKey = "keylight.prefs.restore"

  init() {
    load()
  }

  func isEnabled(for serial: String) -> Bool {
    sleepOffSerials.contains(serial)
  }

  func setEnabled(_ enabled: Bool, for serial: String) {
    if enabled { sleepOffSerials.insert(serial) }
    else { sleepOffSerials.remove(serial) }
    save()
  }

  func isRestoreEnabled(for serial: String) -> Bool {
    restoreSerials.contains(serial)
  }

  func setRestoreEnabled(_ enabled: Bool, for serial: String) {
    if enabled { restoreSerials.insert(serial) }
    else { restoreSerials.remove(serial) }
    saveRestore()
  }

  private func save() {
    UserDefaults.standard.set(Array(sleepOffSerials), forKey: sleepOffKey)
  }

  private func saveRestore() {
    UserDefaults.standard.set(Array(restoreSerials), forKey: restoreKey)
  }

  private func load() {
    if let arr = UserDefaults.standard.stringArray(forKey: sleepOffKey) {
      sleepOffSerials = Set(arr)
    }
    if UserDefaults.standard.object(forKey: restoreKey) != nil {
      if let arr = UserDefaults.standard.stringArray(forKey: restoreKey) {
        restoreSerials = Set(arr)
      }
    } else {
      // First launch with this feature: seed restore from existing sleepOff settings
      // so existing users keep their current behaviour.
      restoreSerials = sleepOffSerials
    }
  }
}
