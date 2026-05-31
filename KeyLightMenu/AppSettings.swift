//
//  AppSettings.swift
//  KeyLightMenu
//

import Foundation
import Observation
import SwiftUI

enum AppearanceMode: String, CaseIterable {
  case system, light, dark

  var title: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

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

  var expandAllLights: Bool = false {
    didSet {
      UserDefaults.standard.set(expandAllLights, forKey: "keylight.settings.expandAllLights")
    }
  }

  var appearanceMode: AppearanceMode = .system {
    didSet {
      UserDefaults.standard.set(appearanceMode.rawValue, forKey: "keylight.settings.appearanceMode")
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
    if UserDefaults.standard.object(forKey: "keylight.settings.expandAllLights") != nil {
      expandAllLights = UserDefaults.standard.bool(forKey: "keylight.settings.expandAllLights")
    }
    if let raw = UserDefaults.standard.string(forKey: "keylight.settings.appearanceMode"),
       let mode = AppearanceMode(rawValue: raw)
    {
      appearanceMode = mode
    }
  }
}
