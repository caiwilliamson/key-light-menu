//
//  MainView.swift
//  KeyLightMenu
//

import SwiftUI

struct MainView: View {
  @Environment(KeyLightService.self) private var service

  @State private var activePanel: Panel?
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
    .task { service.startSession() }
    .onAppear {
      sync.isOptionHeld = NSEvent.modifierFlags.contains(.option) && activePanel == nil
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
        let held = event.modifierFlags.contains(.option)
        sync.isOptionHeld = held && activePanel == nil
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
      Text("Key Light Menu")
        .font(.headline)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var mainContent: some View {
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
          if activePanel == nil {
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
