//
//  PresetChip.swift
//  KeyLightMenu
//

import SwiftUI

struct PresetChip: View {
  @Environment(KeyLightService.self) private var service
  let preset: Preset
  let isActive: Bool
  let index: Int

  var body: some View {
    Button {
      Task { await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature, at: index) }
    } label: {
      Text(preset.name)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(isActive ? Color.accentColor : Color.clear, in: Capsule())
        .overlay(Capsule().strokeBorder(isActive ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1))
        .foregroundStyle(isActive ? Color.white : Color.secondary)
        .font(.callout)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}
