//
//  SettingsView.swift
//  KeyLightMenu
//

import SwiftUI

struct SettingsView: View {
  @Environment(KeyLightService.self) private var service
  let light: KeyLight
  let info: AccessoryInfo
  let index: Int

  @State private var displayNameDraft = ""

  var body: some View {
    VStack(spacing: 0) {
      PanelSection {
        HStack {
          Text("Display Name")
          TextField("None", text: $displayNameDraft)
            .textFieldStyle(.roundedBorder)
            .onSubmit { saveDisplayName() }
          if displayNameDraft != info.displayName {
            Button("Save", action: saveDisplayName)
              .buttonStyle(.borderedProminent)
          }
        }
      }

      Divider().padding(.horizontal, 12)

      if let battery = light.settings?.battery {
        BatterySettingsView(battery: battery, index: index)
          .environment(service)
        Divider().padding(.horizontal, 12)
      }

      if let settings = light.settings {
        PowerOnSettingsView(settings: settings, index: index)
          .environment(service)
        Divider().padding(.horizontal, 12)
      }

      PanelSection {
        let serial = info.serialNumber
        SettingToggleRow(
          label: "Turn Off Automatically",
          subtitle: "Turn the light off when your Mac sleeps or locks, and restore it on wake.",
          isOn: Binding(
            get: { service.lightPrefs.isEnabled(for: serial) },
            set: { service.lightPrefs.setEnabled($0, for: serial) }
          ),
          onChange: {}
        )
      }
    }
    .onAppear { displayNameDraft = info.displayName }
    .onChange(of: info.displayName) { _, new in displayNameDraft = new }
  }

  private func saveDisplayName() {
    Task { await service.setDisplayName(displayNameDraft, at: index) }
  }
}
