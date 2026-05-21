//
//  MainView.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct MainView: View {
  @Environment(KeyLightService.self) private var service
  @Environment(SceneStore.self) private var sceneStore

  @State private var activePanel: Panel?
  @State private var showGlobalSettings = false
  @State private var showScenes = false
  @State private var isCreatingScene = false
  @State private var sync = SyncCoordinator()
  @State private var eventMonitor: Any?

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      mainContent
      Divider()
      footer
    }
    .environment(sync)
    .frame(width: 320)
    .animation(.rowSpring, value: service.selectedIndex)
    .animation(.rowSpring, value: activePanel)
    .animation(.rowSpring, value: sync.isOptionHeld)
    .animation(.rowSpring, value: showGlobalSettings)
    .animation(.rowSpring, value: showScenes)
    .animation(.rowSpring, value: sceneStore.scenes.isEmpty)
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
                .help("New Scene")
            }
            .buttonStyle(.plain)
          }
        }
      } else if showGlobalSettings {
        BreadcrumbHeader(
          homeAction: { showGlobalSettings = false },
          crumbs: [.init(title: "Settings")]
        )
      } else {
        defaultHeader
      }
    }
    .frame(height: 44)
  }

  private var defaultHeader: some View {
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
          .foregroundStyle(showScenes ? Color.accentColor : Color.secondary)
          .font(.system(size: 16))
          .help("Scenes")
      }
      .buttonStyle(.plain)
      Button {
        showGlobalSettings.toggle()
        if showGlobalSettings {
          showScenes = false
          isCreatingScene = false
        }
      } label: {
        Image(systemName: showGlobalSettings ? "gearshape.fill" : "gearshape")
          .foregroundStyle(showGlobalSettings ? Color.accentColor : Color.secondary)
          .font(.system(size: 16))
          .help("App Settings")
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var mainContent: some View {
    if showScenes {
      ScenesView(isCreating: $isCreatingScene)
        .transition(.rowContent)
        .fixedSize(horizontal: false, vertical: true)
    } else if showGlobalSettings {
      GlobalSettingsView()
        .transition(.rowContent)
    } else {
      if !sceneStore.scenes.isEmpty {
        scenesPanel
        Divider()
      }
      if service.lights.isEmpty {
        if service.isDiscovering {
          LoadingState(label: "Scanning…")
        } else {
          noLightsView
        }
      } else {
        ForEach(service.lights.indices, id: \.self) { i in
          if i > 0 { Divider() }
          LightRow(light: service.lights[i], index: i, activePanel: $activePanel)
            .grayscale(!sync.isOptionHeld && activePanel != nil && service.selectedIndex != i ? 1 : 0)
            .opacity(!sync.isOptionHeld && activePanel != nil && service.selectedIndex != i ? 0.4 : 1)
            .allowsHitTesting(sync.isOptionHeld || activePanel == nil || service.selectedIndex == i)
        }
      }
    }
  }

  private var scenesPanel: some View {
    PanelSection(spacing: 6) {
      HFlow(itemSpacing: 6, rowSpacing: 6) {
        ForEach(sceneStore.scenes) { scene in
          SceneChip(scene: scene)
        }
      }
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
            .transition(.rowContent)
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
