//
//  InfoPanel.swift
//  KeyLightMenu
//

import SwiftUI

struct InfoPanel: View {
    @Environment(KeyLightService.self) private var service
    let light: KeyLight
    let info: AccessoryInfo

    @State private var displayNameDraft = ""

    var body: some View {
        VStack(spacing: 0) {

            // Display Name
            PanelSection {
                HStack {
                    Text("Display Name")
                        .foregroundStyle(.secondary)
                    TextField("None", text: $displayNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveDisplayName() }
                    if displayNameDraft != info.displayName {
                        Button("Save", action: saveDisplayName)
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            // Battery Settings
            if let battery = service.selectedLight?.settings?.battery {
                SectionDivider()
                BatteryPanel(battery: battery)
                    .environment(service)
            }

            SectionDivider()

            // Device Info
            PanelSection {
                InfoRow("Device", info.shortProductName)
                InfoRow("Firmware Version", "\(info.firmwareVersion) (\(info.firmwareBuildNumber))")
                InfoRow("Serial Number", info.serialNumber)
                InfoRow("IP Address", light.host)
            }

            if let wifi = info.wifiInfo {
                SectionDivider()
                PanelSection {
                    InfoRow("Wi-Fi Network", wifi.ssid)
                    InfoRow("Wi-Fi Frequency", wifi.frequencyGHz)
                    InfoRow("Wi-Fi Signal Strength", "\(wifi.signalPercent)%")
                }
            }

            SectionDivider()

            PanelSection {
                Button {
                    Task { await service.identify() }
                } label: {
                    Label("Identify Accessory", systemImage: "light.beacon.max")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
            }
        }
        .onAppear { displayNameDraft = info.displayName }
        .onChange(of: info.displayName) { _, new in displayNameDraft = new }
    }

    private func saveDisplayName() {
        Task { await service.setDisplayName(displayNameDraft) }
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
                .frame(width: 130, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
