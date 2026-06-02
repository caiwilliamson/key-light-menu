//
//  Models.swift
//  KeyLightMenu
//

import Foundation

// MARK: - KeyLight

struct KeyLight: Identifiable {
  var id = UUID()
  var discoveredName: String
  var host: String
  var port: Int
  var state: LightState?
  var accessoryInfo: AccessoryInfo?
  var settings: LightSettings?
  var batteryInfo: BatteryInfo?
  var isReachable: Bool = true
  var actionError: String?

  /// Prefers displayName, then productName, then the Bonjour-discovered name.
  var name: String {
    guard let info = accessoryInfo else { return discoveredName }
    return info.displayName.isEmpty ? discoveredName : info.displayName
  }

  func url(_ path: String) -> URL? {
    URL(string: "http://\(host):\(port)/elgato/\(path)")
  }

  var serial: String {
    accessoryInfo?.serialNumber ?? "\(host):\(port)"
  }
}

// MARK: - Helpers

extension Double {
  var kelvinLabel: String {
    "\(Int(1_000_000 / rounded()))K"
  }
}

// MARK: - Light State

struct LightState: Codable, Equatable {
  var on: Int
  var brightness: Int
  var temperature: Int

  var isOn: Bool {
    get { on == 1 }
    set { on = newValue ? 1 : 0 }
  }
}

struct LightsResponse: Codable {
  var numberOfLights: Int
  var lights: [LightState]
}

// MARK: - Accessory Info

struct AccessoryInfo: Codable {
  var productName: String
  var hardwareBoardType: Int
  var hardwareRevision: Double?
  var macAddress: String?
  var firmwareBuildNumber: Int
  var firmwareVersion: String
  var serialNumber: String
  var displayName: String
  var features: [String]
  var wifiInfo: WifiInfo?

  enum CodingKeys: String, CodingKey {
    case productName, hardwareBoardType, hardwareRevision, macAddress
    case firmwareBuildNumber, firmwareVersion, serialNumber, displayName, features
    case wifiInfo = "wifi-info"
  }

  /// Strips the "Elgato " brand prefix for a shorter display name.
  var shortProductName: String {
    productName.hasPrefix("Elgato ") ? String(productName.dropFirst(7)) : productName
  }
}

struct WifiInfo: Codable {
  var ssid: String
  var frequencyMHz: Int
  var rssi: Int

  /// Maps RSSI to signal quality matching Elgato Control Center (0% at -130 dBm, 100% at -30 dBm).
  var signalPercent: Int {
    max(0, min(100, rssi + 130))
  }

  var frequencyGHz: String {
    String(format: "%.1f GHz", Double(frequencyMHz) / 1000.0)
  }
}

// MARK: - Light Settings

struct LightSettings: Codable, Equatable {
  var powerOnBehavior: Int
  var powerOnBrightness: Int
  var powerOnTemperature: Int
  var switchOnDurationMs: Int
  var switchOffDurationMs: Int
  var colorChangeDurationMs: Int
  var battery: BatteryConfig?
}

struct BatteryConfig: Codable, Equatable {
  var energySaving: EnergySavingConfig
  var bypass: Int
}

struct EnergySavingConfig: Codable, Equatable {
  var enable: Int
  var minimumBatteryLevel: Double
  var disableWifi: Int
  var adjustBrightness: AdjustBrightnessConfig
}

struct AdjustBrightnessConfig: Codable, Equatable {
  var enable: Int
  var brightness: Double
}

// MARK: - Battery Info

struct BatteryInfo: Codable {
  var powerSource: Int // 1 = plugged-in, 2 = on battery
  var level: Double // 0–100
  var status: Int
  var currentBatteryVoltage: Int
  var inputChargeVoltage: Int
  var inputChargeCurrent: Int

  var isPluggedIn: Bool {
    powerSource == 1
  }

  var isCharging: Bool {
    isPluggedIn && currentBatteryVoltage > 0
  }
}

// MARK: - Cache

struct CachedLight: Codable {
  var host: String
  var port: Int
  var discoveredName: String
  var state: LightState?
  var accessoryInfo: AccessoryInfo?
  var settings: LightSettings?
  var isReachable: Bool
}
