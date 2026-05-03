//
//  PowerOnSettingsView.swift
//  KeyLightMenu
//

import SwiftUI

struct PowerOnSettingsView: View {
  @Environment(KeyLightService.self) private var service
  var settings: LightSettings
  let index: Int

  @State private var behavior: Int
  @State private var brightness: Double
  @State private var temperature: Double
  @State private var sendTask: Task<Void, Never>?

  init(settings: LightSettings, index: Int) {
    self.settings = settings
    self.index = index
    _behavior = State(initialValue: settings.powerOnBehavior)
    _brightness = State(initialValue: Double(settings.powerOnBrightness))
    _temperature = State(initialValue: Double(settings.powerOnTemperature))
  }

  var body: some View {
    PanelSection {
      HStack {
        Text("Power On Behaviour")
        Spacer()
        Picker("", selection: $behavior) {
          Text("Restore Last Used").tag(1)
          Text("Restore Defaults").tag(2)
        }
        .labelsHidden()
        .fixedSize()
        .onChange(of: behavior) { _, _ in send() }
      }

      if behavior == 2 {
        SettingSliderRow(
          icon: "sun.max.fill",
          value: $brightness,
          range: 1 ... 100,
          format: { "\(Int($0))%" },
          onCommit: send
        )
        SettingSliderRow(
          icon: "thermometer.medium",
          value: $temperature,
          range: 143 ... 344,
          format: { "\(Int(1_000_000 / $0.rounded()))K" },
          onCommit: send
        )
      }
    }
    .onChange(of: settings) { _, new in
      behavior = new.powerOnBehavior
      brightness = Double(new.powerOnBrightness)
      temperature = Double(new.powerOnTemperature)
    }
  }

  private func send() {
    sendTask?.cancel()
    sendTask = Task {
      await service.setPowerOnSettings(
        behavior: behavior,
        brightness: Int(brightness),
        temperature: Int(temperature),
        at: index
      )
    }
  }
}
