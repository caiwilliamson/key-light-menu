//
//  Models.swift
//  KeyLightMenu
//

import Foundation

// MARK: - Light Models

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

struct WifiInfo: Codable {
    var ssid: String
    var frequencyMHz: Int
    var rssi: Int

    /// Maps RSSI to signal quality matching Elgato Control Center (0% at -130 dBm, 100% at -30 dBm).
    var signalPercent: Int { max(0, min(100, rssi + 130)) }

    var frequencyGHz: String { String(format: "%.1f GHz", Double(frequencyMHz) / 1000.0) }
}

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

// MARK: - Settings Models

struct AdjustBrightnessConfig: Codable, Equatable {
    var enable: Int
    var brightness: Double
}

struct EnergySavingConfig: Codable, Equatable {
    var enable: Int
    var minimumBatteryLevel: Double
    var disableWifi: Int
    var adjustBrightness: AdjustBrightnessConfig
}

struct BatteryConfig: Codable, Equatable {
    var energySaving: EnergySavingConfig
    var bypass: Int
}

struct LightSettings: Codable {
    var powerOnBehavior: Int
    var powerOnBrightness: Int
    var powerOnTemperature: Int
    var switchOnDurationMs: Int
    var switchOffDurationMs: Int
    var colorChangeDurationMs: Int
    var battery: BatteryConfig?
}

// MARK: - Cache

struct CachedLight: Codable {
    var host: String
    var port: Int
    var discoveredName: String
    var state: LightState?
    var accessoryInfo: AccessoryInfo?
    var settings: LightSettings?
}
