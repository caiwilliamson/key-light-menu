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
  @State private var headerHeight: CGFloat = 0
  @State private var availableScreenHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? 800

  var body: some View {
    VStack(spacing: 0) {
      header
        .background(GeometryReader { geo in
          Color.clear.preference(key: HeaderHeightKey.self, value: geo.size.height)
        })
      Divider()
      ScrollView {
        VStack(spacing: 0) {
          mainContent
        }
        .background(GeometryReader { geo in
          Color.clear.preference(key: ScrollContentHeightKey.self, value: geo.size.height)
        })
      }
      .frame(height: min(scrollContentHeight, max(0, availableScreenHeight - headerHeight - 1 - 12)))
      .onPreferenceChange(ScrollContentHeightKey.self) { scrollContentHeight = $0 }
    }
    .environment(sync)
    .frame(width: 340)
    .tooltipContainer()
    .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      DispatchQueue.main.async {
        if let screen = NSApp.keyWindow?.screen {
          availableScreenHeight = screen.visibleFrame.height
        }
      }
    }
    .task { service.startSession() }
    .onAppear {
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        // Only act on the key-down transition (option becoming pressed)
        guard event.modifierFlags.contains(.option) else { return event }
        guard activePanel == nil, !showGlobalSettings, !showScenes else { return event }
        guard service.lights.filter(\.isReachable).count >= 2 else { return event }
        sync.isOptionHeld.toggle()
        if !sync.isOptionHeld { sync.reset() }
        return event
      }
    }
    .onDisappear {
      if let monitor = eventMonitor {
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
      }
      sync.isOptionHeld = false
      sync.reset()
      sync.isReordering = false
    }
    .onChange(of: service.selectedLight?.host) { _, new in
      if new == nil { activePanel = nil }
    }
    .onChange(of: service.selectedLight?.isReachable) { _, reachable in
      if reachable == false, activePanel != .remove { activePanel = nil }
    }
    .onChange(of: activePanel) { _, new in
      if new != .presets { isCreatingPreset = false }
      if new != nil { sync.isReordering = false }
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
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Text("Key Light Menu")
          .font(.headline)
        Spacer()
        if sync.isOptionHeld {
          Image(systemName: "link")
            .foregroundStyle(.secondary)
          Text("Sliders Linked (⌥)")
            .font(.callout)
            .foregroundStyle(.secondary)
          Button {
            sync.isOptionHeld = false; sync.reset()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .tooltip("Exit Mode")
        } else if sync.isReordering {
          Image(systemName: "arrow.up.arrow.down")
            .foregroundStyle(.secondary)
          Text("Reorder Lights")
            .font(.callout)
            .foregroundStyle(.secondary)
          Button {
            sync.isReordering = false
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .tooltip("Exit Mode")
        } else {
          Menu {
            Button {
              showGlobalSettings = true
              showScenes = false
              isCreatingScene = false
            } label: { Label("App Settings", systemImage: "gearshape") }
            Button {
              showScenes = true
              showGlobalSettings = false
              isCreatingScene = false
            } label: { Label("Scenes", systemImage: "sparkles") }
            Divider()
            Button {
              for i in service.lights.indices where service.lights[i].isReachable {
                Task { await service.setOn(true, at: i) }
              }
            } label: { Label("Turn All Lights On", systemImage: "power.circle.fill") }
              .disabled(!service.lights.contains { $0.isReachable && $0.state?.isOn == false })
            Button {
              for i in service.lights.indices where service.lights[i].isReachable {
                Task { await service.setOn(false, at: i) }
              }
            } label: { Label("Turn All Lights Off", systemImage: "power.circle") }
              .disabled(!service.lights.contains { $0.isReachable && $0.state?.isOn == true })
            Button {
              sync.isOptionHeld = true
            } label: { Label("Link Sliders ⌥", systemImage: "link") }
              .disabled(service.lights.filter(\.isReachable).count < 2)
            Button {
              sync.isReordering = true
            } label: { Label("Reorder Lights", systemImage: "arrow.up.arrow.down") }
              .disabled(service.lights.count < 2)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
          } label: {
            Image(systemName: "ellipsis")
              .foregroundStyle(Color.secondary)
          }
          .menuStyle(.borderlessButton)
          .menuIndicator(.hidden)
          .fixedSize()
          .tooltip("Options")
        }
      }
      .frame(height: 20)
      if !sceneStore.scenes.isEmpty {
        SceneChipsRow {
          ForEach(sceneStore.scenes) { scene in
            SceneChip(scene: scene)
          }
        }
        .padding(.top, 6)
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
        LoadingView(
          label: "Searching for lights…",
          hint: "To connect a new light, open the Wi-Fi menu, choose it under \"New Accessories\", and follow the steps in AirPort Utility."
        )
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
        LoadingView(label: "Loading…")
      }
    case .settings:
      if let info = light.accessoryInfo {
        SettingsView(light: light, info: info, index: index)
      } else {
        LoadingView(label: "Loading…")
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
}

private struct HeaderHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct ScrollContentHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
