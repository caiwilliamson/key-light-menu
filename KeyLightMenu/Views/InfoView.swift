//
//  InfoView.swift
//  KeyLightMenu
//

import SwiftUI

struct InfoView: View {
  @Environment(KeyLightService.self) private var service
  let light: KeyLight
  let info: AccessoryInfo
  let index: Int

  var body: some View {
    VStack(spacing: 0) {
      PanelSection(spacing: 6) {
        InfoRow("Device", info.shortProductName)
        InfoRow("Firmware Version", "\(info.firmwareVersion) (\(info.firmwareBuildNumber))")
        InfoRow("Serial Number", info.serialNumber)
        InfoRow("IP Address", light.host)
      }

      if let wifi = info.wifiInfo {
        PanelSection(spacing: 6) {
          InfoRow("Wi-Fi Network", wifi.ssid)
          InfoRow("Wi-Fi Frequency", wifi.frequencyGHz)
          InfoRow("Wi-Fi Signal Strength", "\(wifi.signalPercent)%")
        }
      }

      PanelSection(spacing: 6) {
        Button {
          Task { await service.identify(at: index) }
        } label: {
          Label("Identify Accessory", systemImage: "light.beacon.max")
            .frame(maxWidth: .infinity)
        }
      }
    }
  }
}

// MARK: - InfoRow

struct InfoRow: View {
  let label: String
  let value: String

  init(_ label: String, _ value: String) {
    self.label = label
    self.value = value
  }

  var body: some View {
    HStack {
      Text(label + ":")
        .foregroundStyle(.secondary)
        .frame(width: 140, alignment: .leading)
      Text(value)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
