//
//  PresetsView.swift
//  KeyLightMenu
//

import SwiftUI

struct PresetsView: View {
    @Environment(KeyLightService.self) private var service
    @Environment(PresetStore.self) private var store

    @State private var presetName = ""

    var body: some View {
        let serial = service.selectedLight?.accessoryInfo?.serialNumber ?? ""
        let hostPresets = store.presets(for: serial)
        return VStack(spacing: 0) {
            if let state = service.selectedLight?.state {
                PanelSection {
                    Text("New Preset")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LightSlider(
                        icon: "sun.max.fill",
                        value: Double(state.brightness),
                        range: 1...100,
                        label: { v in "\(Int(v))%" }
                    ) { v in Task { await service.setBrightness(Int(v)) } }

                    LightSlider(
                        icon: "thermometer.medium",
                        value: Double(state.temperature),
                        range: 143...344,
                        label: { v in "\(Int(1_000_000 / v.rounded()))K" }
                    ) { v in Task { await service.setTemperature(Int(v)) } }

                    HStack(spacing: 8) {
                        Color.clear.frame(width: 20)
                        TextField("Preset name", text: $presetName)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            guard !presetName.isEmpty, let state = service.selectedLight?.state else { return }
                            store.add(
                                name: presetName,
                                brightness: state.brightness,
                                temperature: state.temperature,
                                lightSerial: serial
                            )
                            presetName = ""
                        }
                        .disabled(presetName.isEmpty || service.selectedLight?.state == nil)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            if hostPresets.isEmpty {
                SectionDivider()
                PanelSection {
                    Text("No saved presets")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                SectionDivider()
                VStack(spacing: 0) {
                    ForEach(hostPresets) { preset in
                        PanelSection {
                            HStack {
                                Text(preset.name)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    store.delete(preset)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            previewRow(icon: "sun.max.fill", value: Double(preset.brightness), range: 1...100, label: "\(preset.brightness)%")
                            previewRow(icon: "thermometer.medium", value: Double(preset.temperature), range: 143...344, label: "\(Int(1_000_000 / Double(preset.temperature)))K")
                        }
                    }
                }
            }
        }
    }

    private func previewRow(icon: String, value: Double, range: ClosedRange<Double>, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Slider(value: .constant(value), in: range)
                .allowsHitTesting(false)
                .tint(.gray)
                .controlSize(.small)
            Text(label)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
