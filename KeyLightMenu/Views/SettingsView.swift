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
  @State private var saveError: String?

  var body: some View {
    PanelSection {
      HStack {
        Text("Display Name")
        TextField("None", text: $displayNameDraft)
          .textFieldStyle(.roundedBorder)
          .onChange(of: displayNameDraft) { _, new in if new.count > 20 { displayNameDraft = String(new.prefix(20)) } }
          .onSubmit { saveDisplayName() }
        if displayNameDraft != info.displayName {
          Button("Save", action: saveDisplayName)
            .buttonStyle(.borderedProminent)
        }
      }
      if let err = saveError {
        Text(err).font(.callout).foregroundStyle(.red)
      }
      if let battery = light.settings?.battery {
        Divider()
        BatterySettingsView(battery: battery, index: index)
          .environment(service)
      }
      if let settings = light.settings {
        Divider()
        PowerOnSettingsView(settings: settings, index: index)
          .environment(service)
      }
      Divider()
      let serial = info.serialNumber
      SettingToggleRow(
        label: "Turn Off When Mac Sleeps",
        subtitle: "Turn the light off when your Mac sleeps or locks.",
        isOn: Binding(
          get: { service.lightPrefs.isEnabled(for: serial) },
          set: { service.lightPrefs.setEnabled($0, for: serial) }
        ),
        onChange: {}
      )
      if service.lightPrefs.isEnabled(for: serial) {
        SettingToggleRow(
          label: "Turn Back On When Mac Wakes",
          subtitle: "Turn the light back on when your Mac wakes or unlocks, restoring its previous settings.",
          isOn: Binding(
            get: { service.lightPrefs.isRestoreEnabled(for: serial) },
            set: { service.lightPrefs.setRestoreEnabled($0, for: serial) }
          ),
          onChange: {}
        )
      }
    }
    .onAppear { displayNameDraft = info.displayName }
    .onChange(of: info.displayName) { _, new in displayNameDraft = new }
  }

  private func saveDisplayName() {
    Task {
      do {
        try await service.setDisplayName(displayNameDraft, at: index)
        saveError = nil
      } catch {
        saveError = "Couldn't save — try again"
      }
    }
  }
}
