//
//  MainView.swift
//  KeyLightMenu
//

import SwiftUI

enum ActiveSection { case globalSettings, scenes }

struct MainView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(PresetStore.self) private var store
  @Environment(SceneStore.self) private var sceneStore

  @State private var activePanel: Panel?
  @State private var activeSection: ActiveSection?
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
    .onAppear { setupEventMonitor() }
    .onDisappear { teardownEventMonitor() }
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

  // MARK: - Event Monitor

  private func setupEventMonitor() {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
      guard event.modifierFlags.contains(.option) else { return event }
      guard activePanel == nil, activeSection == nil else { return event }
      guard service.lights.filter(\.isReachable).count >= 2 else { return event }
      sync.isOptionHeld.toggle()
      if !sync.isOptionHeld { sync.reset() }
      return event
    }
  }

  private func teardownEventMonitor() {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
    sync.isOptionHeld = false
    sync.reset()
    sync.isReordering = false
  }

  // MARK: - Header

  private var header: some View {
    PanelSection {
      MainHeader(
        activeSection: $activeSection,
        activePanel: $activePanel,
        isCreatingScene: $isCreatingScene,
        isCreatingPreset: $isCreatingPreset
      )
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var mainContent: some View {
    if activeSection == .scenes {
      ScenesView(isCreating: $isCreatingScene)
        .fixedSize(horizontal: false, vertical: true)
    } else if activeSection == .globalSettings {
      GlobalSettingsView()
    } else if let panel = activePanel, let idx = service.selectedIndex,
              service.lights.indices.contains(idx)
    {
      lightPanelContent(index: idx, panel: panel)
    } else {
      if service.lights.isEmpty {
        PlaceholderView(
          label: "Searching for lights…",
          hint: "To connect a new light, open the Wi-Fi menu, choose it under \"New Accessories\", and follow the steps in AirPort Utility."
        ) { ProgressView().controlSize(.small) }
      } else {
        ForEach(service.lights) { light in
          let i = service.lights.firstIndex(where: { $0.id == light.id }) ?? 0
          if !sync.isOptionHeld || light.isReachable {
            if i > 0 {
              let precedingVisible = !sync.isOptionHeld || service.lights[0 ..< i].contains { $0.isReachable }
              if precedingVisible {
                Divider()
                  .transaction { $0.animation = nil }
              }
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
      withAccessoryInfo(light) { InfoView(light: light, info: $0, index: index) }
    case .settings:
      withAccessoryInfo(light) { SettingsView(light: light, info: $0, index: index) }
    case .presets:
      PresetsView(light: light, index: index, isCreating: $isCreatingPreset)
        .environment(store)
        .fixedSize(horizontal: false, vertical: true)
    case .remove:
      RemoveLightView(light: light, index: index, activePanel: $activePanel)
        .environment(store)
    }
  }

  @ViewBuilder
  private func withAccessoryInfo<V: View>(_ light: KeyLight, @ViewBuilder content: (AccessoryInfo) -> V) -> some View {
    if let info = light.accessoryInfo {
      content(info)
    } else {
      PlaceholderView(label: "Loading…") { ProgressView().controlSize(.small) }
    }
  }
}

private protocol MaxCGFloatPreferenceKey: PreferenceKey where Value == CGFloat {}
extension MaxCGFloatPreferenceKey {
  static var defaultValue: CGFloat { 0 }
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct HeaderHeightKey: MaxCGFloatPreferenceKey {}
private struct ScrollContentHeightKey: MaxCGFloatPreferenceKey {}
