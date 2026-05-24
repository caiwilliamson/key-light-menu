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

  var showBatteryPercentage: Bool = false {
    didSet {
      UserDefaults.standard.set(showBatteryPercentage, forKey: "keylight.settings.showBatteryPercentage")
    }
  }

  var showWifiSignalPercentage: Bool = false {
    didSet {
      UserDefaults.standard.set(showWifiSignalPercentage, forKey: "keylight.settings.showWifiSignalPercentage")
    }
  }

  init() {
    if UserDefaults.standard.object(forKey: "keylight.settings.turnOnLightsWithScene") != nil {
      turnOnLightsWithScene = UserDefaults.standard.bool(forKey: "keylight.settings.turnOnLightsWithScene")
    }
    if UserDefaults.standard.object(forKey: "keylight.settings.turnOnLightWithPreset") != nil {
      turnOnLightWithPreset = UserDefaults.standard.bool(forKey: "keylight.settings.turnOnLightWithPreset")
    }
    if UserDefaults.standard.object(forKey: "keylight.settings.showBatteryPercentage") != nil {
      showBatteryPercentage = UserDefaults.standard.bool(forKey: "keylight.settings.showBatteryPercentage")
    }
    if UserDefaults.standard.object(forKey: "keylight.settings.showWifiSignalPercentage") != nil {
      showWifiSignalPercentage = UserDefaults.standard.bool(forKey: "keylight.settings.showWifiSignalPercentage")
    }
  }
}
