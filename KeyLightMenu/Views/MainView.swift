//
//  MainView.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct MainView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store

  private enum Panel { case info, presets, settings }
  @State private var activePanel: Panel?

  var body: some View {
    VStack(spacing: 0) {
      header
      SectionDivider()
      mainContent
      footer
    }
    .frame(width: 320)
    .font(.callout)
    .task { service.startSession() }
    .onChange(of: service.selectedLight?.host) { _, new in
      if new == nil { activePanel = nil }
    }
  }

  // MARK: - Header

  private var header: some View {
    PanelSection {
      if let light = service.selectedLight {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(light.name)
              .font(.headline)
              .lineLimit(1)

            Spacer()

            panelButton(.presets, active: "slider.horizontal.3", inactive: "slider.horizontal.3")
            panelButton(.settings, active: "gearshape.fill", inactive: "gearshape")
            panelButton(.info, active: "info.circle.fill", inactive: "info.circle")

            if let state = light.state {
              Button {
                Task { await service.toggle() }
              } label: {
                Image(systemName: state.isOn ? "power.circle.fill" : "power.circle")
                  .font(.title)
                  .foregroundStyle(state.isOn ? Color.yellow : Color.secondary)
                  .contentTransition(.symbolEffect(.replace))
              }
              .buttonStyle(.plain)
            }
          }

          Text(light.isReachable ? (light.state?.isOn == true ? "On" : "Off") : "Disconnected")
            .foregroundStyle(.secondary)
        }
      } else {
        Text("Key Light Menu")
          .font(.headline)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func panelButton(_ panel: Panel, active: String, inactive: String) -> some View {
    Button { activePanel = activePanel == panel ? nil : panel } label: {
      Image(systemName: activePanel == panel ? active : inactive)
        .font(.title2)
        .foregroundStyle(activePanel == panel ? Color.accentColor : Color.secondary)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Content

  @ViewBuilder
  private var mainContent: some View {
    if let light = service.selectedLight {
      lightContent(for: light)
    } else if service.isDiscovering {
      scanningView
    } else {
      noLightView
    }
  }

  @ViewBuilder
  private func lightContent(for light: KeyLight) -> some View {
    if !light.isReachable {
      disconnectedView
    } else {
      switch activePanel {
      case .info:
        if let info = light.accessoryInfo {
          InfoView(light: light, info: info).environment(service)
        } else {
          loadingView
        }
      case .settings:
        if let info = light.accessoryInfo {
          SettingsView(light: light, info: info).environment(service)
        } else {
          loadingView
        }
      case .presets:
        PresetsView()
          .environment(service)
          .environment(store)
          .fixedSize(horizontal: false, vertical: true)
      case nil:
        if let state = light.state {
          controlsPanel(state: state, light: light)
        } else if service.isLoading {
          loadingView
        }
      }
    }
  }

  @ViewBuilder
  private func controlsPanel(state: LightState, light: KeyLight) -> some View {
    let presets = store.presets(for: light.accessoryInfo?.serialNumber ?? "")
    PanelSection {
      LightSlider(
        icon: "sun.max.fill",
        value: Double(state.brightness),
        range: 1 ... 100,
        label: { "\(Int($0))%" }
      ) { v in Task { await service.setBrightness(Int(v)) } }

      LightSlider(
        icon: "thermometer.medium",
        value: Double(state.temperature),
        range: 143 ... 344,
        label: { "\(Int(1_000_000 / $0.rounded()))K" }
      ) { v in Task { await service.setTemperature(Int(v)) } }

      if !presets.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "slider.horizontal.3")
            .frame(width: 20)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
          HFlow(itemSpacing: 6, rowSpacing: 6) {
            ForEach(presets) { preset in
              Button(preset.name) {
                Task { await service.applyPreset(brightness: preset.brightness, temperature: preset.temperature) }
              }
            }
          }
        }
      }
    }
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: 0) {
      SectionDivider()

      if service.lights.count > 1 {
        PanelSection {
          Picker("", selection: Binding(get: { service.selectedIndex }, set: { service.selectedIndex = $0 })) {
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
          Text(err).foregroundStyle(.red).lineLimit(2)
        }
        SectionDivider()
      }

      PanelSection {
        HStack {
          if activePanel == nil {
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
          Button("Quit") { NSApplication.shared.terminate(nil) }
        }
      }
    }
  }

  // MARK: - State Views

  private var loadingView: some View { stateView(label: "Loading…") }
  private var scanningView: some View { stateView(label: "Scanning…") }
  private var disconnectedView: some View { stateView(icon: "bolt.slash", label: "Light disconnected") }
  private var noLightView: some View { stateView(icon: "lightbulb.slash", label: "No lights found") }

  @ViewBuilder
  private func stateView(icon: String? = nil, label: String) -> some View {
    VStack(spacing: 8) {
      if let icon {
        Image(systemName: icon)
          .font(.largeTitle)
          .foregroundStyle(.secondary)
      } else {
        ProgressView()
      }
      Text(label)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
  }
}
