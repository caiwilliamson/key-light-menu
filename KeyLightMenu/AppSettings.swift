//
//  AppSettings.swift
//  KeyLightMenu
//

import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
  var turnOnLightsWithScene: Bool = true {
    didSet {
      UserDefaults.standard.set(turnOnLightsWithScene, forKey: "keylight.settings.turnOnLightsWithScene")
    }
  }

  var turnOnLightWithPreset: Bool = true {
    didSet {
      UserDefaults.standard.set(turnOnLightWithPreset, forKey: "keylight.settings.turnOnLightWithPreset")
    }
  }

  init() {
    if UserDefaults.standard.object(forKey: "keylight.settings.turnOnLightsWithScene") != nil {
      turnOnLightsWithScene = UserDefaults.standard.bool(forKey: "keylight.settings.turnOnLightsWithScene")
    }
    if UserDefaults.standard.object(forKey: "keylight.settings.turnOnLightWithPreset") != nil {
      turnOnLightWithPreset = UserDefaults.standard.bool(forKey: "keylight.settings.turnOnLightWithPreset")
    }
  }
}
