//
//  MainView.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct MainView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store
  @Environment(SceneStore.self) private var sceneStore

  @State private var activePanel: Panel?
  @State private var showGlobalSettings = false
  @State private var showScenes = false
  @State private var isCreatingScene = false
  @State private var isCreatingPreset = false
  @State private var sync = SyncCoordinator()
  @State private var eventMonitor: Any?
  @State private var scrollContentHeight: CGFloat = 0

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(spacing: 0) {
          mainContent
        }
        .background(GeometryReader { geo in
          Color.clear.preference(key: ScrollContentHeightKey.self, value: geo.size.height)
        })
      }
      .frame(height: min(scrollContentHeight, 500))
      .onPreferenceChange(ScrollContentHeightKey.self) { scrollContentHeight = $0 }

      Divider()
      footer
    }
    .environment(sync)
    .frame(width: 340)
    .tooltipContainer()
    .task { service.startSession() }
    .onAppear {
      sync.isOptionHeld = NSEvent.modifierFlags.contains(.option) && activePanel == nil && !showGlobalSettings && !showScenes
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        let held = event.modifierFlags.contains(.option)
        sync.isOptionHeld = held && activePanel == nil && !showGlobalSettings && !showScenes
        if !held { sync.reset() }
        return event
      }
    }
    .onDisappear {
      if let monitor = eventMonitor {
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
      }
    }
    .onChange(of: service.selectedLight?.host) { _, new in
      if new == nil { activePanel = nil }
    }
    .onChange(of: service.selectedLight?.isReachable) { _, reachable in
      if reachable == false, activePanel != .remove { activePanel = nil }
    }
    .onChange(of: activePanel) { _, new in
      if new != .presets { isCreatingPreset = false }
    }
  }

  // MARK: - Header

  private var header: some View {
    PanelSection {
      if showScenes {
        BreadcrumbHeader(
          homeAction: { showScenes = false; isCreatingScene = false },
          crumbs: isCreatingScene
            ? [.init(title: "Scenes", action: { isCreatingScene = false }), .init(title: "New Scene")]
            : [.init(title: "Scenes")]
        ) {
          if !isCreatingScene {
            Button { isCreatingScene = true } label: {
              Image(systemName: "plus")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .tooltip("New Scene")
          }
        }
      } else if showGlobalSettings {
        BreadcrumbHeader(
          homeAction: { showGlobalSettings = false },
          crumbs: [.init(title: "App Settings")]
        )
      } else if let panel = activePanel, let idx = service.selectedIndex,
                service.lights.indices.contains(idx)
      {
        let lightName = service.lights[idx].name
        BreadcrumbHeader(
          homeAction: { activePanel = nil; service.selectedIndex = nil },
          crumbs: panel == .presets && isCreatingPreset
            ? [
              .init(title: lightName, action: { activePanel = nil }),
              .init(title: panel.title, action: { isCreatingPreset = false }),
              .init(title: "New Preset"),
            ]
            : [
              .init(title: lightName, action: { activePanel = nil }),
              .init(title: panel.title),
            ]
        ) {
          if panel == .presets, !isCreatingPreset {
            Button { isCreatingPreset = true } label: {
              Image(systemName: "plus")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            }
            .tooltip("New Preset")
            .buttonStyle(.plain)
          }
        }
      } else {
        defaultHeader
      }
    }
  }

  private var defaultHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 4) {
        Text("Key Light Menu")
          .font(.headline)
        Spacer()
        Button {
          showScenes.toggle()
          if showScenes {
            showGlobalSettings = false
            isCreatingScene = false
          }
        } label: {
          Image(systemName: "sparkles")
            .foregroundStyle(Color.secondary)
            .font(.system(size: 16))
        }
        .buttonStyle(.plain)
        .tooltip("Scenes")
        Button {
          showGlobalSettings.toggle()
          if showGlobalSettings {
            showScenes = false
            isCreatingScene = false
          }
        } label: {
          Image(systemName: "gearshape")
            .foregroundStyle(Color.secondary)
            .font(.system(size: 16))
        }
        .buttonStyle(.plain)
        .tooltip("App Settings")
      }
      .frame(height: 20)
      if !sceneStore.scenes.isEmpty, !sync.isOptionHeld {
        SceneChipsRow {
          ForEach(sceneStore.scenes) { scene in
            SceneChip(scene: scene)
          }
        }
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var mainContent: some View {
    if showScenes {
      ScenesView(isCreating: $isCreatingScene)
        .fixedSize(horizontal: false, vertical: true)
    } else if showGlobalSettings {
      GlobalSettingsView()
    } else if let panel = activePanel, let idx = service.selectedIndex,
              service.lights.indices.contains(idx)
    {
      lightPanelContent(index: idx, panel: panel)
    } else {
      if service.lights.isEmpty {
        if service.isDiscovering {
          LoadingState(label: "Scanning…")
        } else {
          noLightsView
        }
      } else {
        ForEach(service.lights.indices, id: \.self) { i in
          let light = service.lights[i]
          if !sync.isOptionHeld || light.isReachable {
            if i > 0 {
              let precedingVisible = !sync.isOptionHeld || service.lights[0 ..< i].contains { $0.isReachable }
              if precedingVisible { Divider() }
            }
            LightRow(light: light, index: i, activePanel: $activePanel)
              .grayscale(!sync.isOptionHeld && activePanel != nil && service.selectedIndex != i ? 1 : 0)
              .opacity(!sync.isOptionHeld && activePanel != nil && service.selectedIndex != i ? 0.4 : 1)
              .allowsHitTesting(sync.isOptionHeld || activePanel == nil || service.selectedIndex == i)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func lightPanelContent(index: Int, panel: Panel) -> some View {
    let light = service.lights[index]
    switch panel {
    case .info:
      if let info = light.accessoryInfo {
        InfoView(light: light, info: info, index: index)
      } else {
        LoadingState(label: "Loading…")
      }
    case .settings:
      if let info = light.accessoryInfo {
        SettingsView(light: light, info: info, index: index)
      } else {
        LoadingState(label: "Loading…")
      }
    case .presets:
      PresetsView(light: light, index: index, isCreating: $isCreatingPreset)
        .environment(store)
        .fixedSize(horizontal: false, vertical: true)
    case .remove:
      RemoveLightView(light: light, index: index, activePanel: $activePanel)
        .environment(store)
    }
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: 0) {
      if let err = service.errorMessage {
        PanelSection {
          Text(err).foregroundStyle(.red).lineLimit(2)
        }
        SectionDivider()
      }

      PanelSection {
        HStack {
          if activePanel == nil, !showGlobalSettings, !showScenes {
            Button {
              service.startDiscovery()
            } label: {
              Label(service.isDiscovering ? "Scanning…" : "Scan", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(service.isDiscovering)
          }
          Spacer()
          Button("Quit") { NSApplication.shared.terminate(nil) }
        }
      }
    }
  }

  private var noLightsView: some View {
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
}

private struct ScrollContentHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
