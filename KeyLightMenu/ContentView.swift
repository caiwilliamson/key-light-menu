//
//  ContentView.swift
//  KeyLightMenu
//
//  Created by Cai Williamson on 27/04/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(KeyLightService.self) private var service
    @Environment(PresetStore.self) private var store
    @State private var showInfo = false
    @State private var showPresets = false

    var body: some View {
        VStack(spacing: 0) {
            header

            SectionDivider()

            if let light = service.selectedLight {
                if showInfo {
                    if let info = light.accessoryInfo {
                        InfoPanel(light: light, info: info)
                            .environment(service)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("Loading info…").foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                } else if showPresets {
                    PresetsPanel()
                        .environment(service)
                        .environment(store)
                } else if let state = light.state {
                    let hostPresets = store.presets(for: light.host)
                    PanelSection {
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

                        if !hostPresets.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                    .frame(width: 20)
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(hostPresets) { preset in
                                            PresetButton(preset: preset) {
                                                Task { await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else if service.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Connecting…").foregroundStyle(.secondary)
                    }
                    .padding()
                }
            } else if !service.isDiscovering {
                noLightView
            }

            footer
        }
        .frame(width: 280)
        .font(.callout)
        .task { service.startDiscovery() }
        .onChange(of: service.selectedLight?.host) { _, new in
            if new == nil { showInfo = false; showPresets = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        PanelSection {
            HStack(spacing: 6) {
                if let light = service.selectedLight {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(light.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(light.state?.isOn == true ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                } else if service.isDiscovering {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Scanning…").foregroundStyle(.secondary)
                    }
                } else {
                    Text("Key Light Menu")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if service.isLoading && service.selectedLight?.state != nil {
                    ProgressView().scaleEffect(0.7)
                }

                if service.selectedLight != nil {
                    Button {
                        showPresets.toggle()
                        if showPresets { showInfo = false }
                    } label: {
                        Image(systemName: showPresets ? "slider.horizontal.3" : "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(showPresets ? Color.accentColor : Color.secondary)
                            .foregroundStyle(showPresets ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showInfo.toggle()
                        if showInfo { showPresets = false }
                    } label: {
                        Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                            .font(.title2)
                            .foregroundStyle(showInfo ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let state = service.selectedLight?.state {
                    Button {
                        Task { await service.toggle() }
                    } label: {
                        Image(systemName: state.isOn ? "power.circle.fill" : "power.circle")
                            .font(.title2)
                            .foregroundStyle(state.isOn ? Color.yellow : Color.secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty state

    private var noLightView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lightbulb.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No lights found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            SectionDivider()

            if service.lights.count > 1 {
                PanelSection {
                    Picker(
                        "",
                        selection: Binding(
                            get: { service.selectedIndex },
                            set: { service.selectedIndex = $0 }
                        )
                    ) {
                        ForEach(Array(service.lights.enumerated()), id: \.offset) { i, l in
                            Text(l.name).tag(Optional(i))
                        }
                    }
                    .labelsHidden()
                }
                SectionDivider()
            }

            if let err = service.errorMessage {
                PanelSection {
                    Text(err)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                SectionDivider()
            }

            PanelSection {
                HStack {
                    if !showInfo && !showPresets {
                        Button {
                            service.startDiscovery()
                        } label: {
                            Label(
                                service.isDiscovering ? "Scanning…" : "Scan",
                                systemImage: "antenna.radiowaves.left.and.right"
                            )
                        }
                        .disabled(service.isDiscovering)
                    }

                    Spacer()

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }

}


private struct PresetButton: View {
    let preset: Preset
    let action: () -> Void

    var body: some View {
        Button(preset.name, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}

#Preview {
    ContentView()
        .environment(KeyLightService())
}

