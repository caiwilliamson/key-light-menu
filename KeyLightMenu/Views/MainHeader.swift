//
//  MainHeader.swift
//  KeyLightMenu
//

import SwiftUI

struct MainHeader: View {
  @Environment(KeyLightService.self) private var service
  @Environment(SceneStore.self) private var sceneStore
  @Environment(SyncCoordinator.self) private var sync

  @Binding var activeSection: ActiveSection?
  @Binding var activePanel: Panel?
  @Binding var isCreatingScene: Bool
  @Binding var isCreatingPreset: Bool

  var body: some View {
    if activeSection == .scenes {
      BreadcrumbHeader(
        homeAction: { activeSection = nil; isCreatingScene = false },
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
    } else if activeSection == .globalSettings {
      BreadcrumbHeader(
        homeAction: { activeSection = nil },
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
      defaultContent
    }
  }

  private var defaultContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Text("Key Light Menu")
          .font(.headline)
        Spacer()
        if sync.isOptionHeld {
          ModeStatusBadge(icon: "link", label: "Sliders Linked (⌥)") {
            sync.isOptionHeld = false; sync.reset()
          }
        } else if sync.isReordering {
          ModeStatusBadge(icon: "arrow.up.arrow.down", label: "Reorder Lights") {
            sync.isReordering = false
          }
        } else {
          Menu {
            Button {
              activeSection = .globalSettings
            } label: { Label("App Settings", systemImage: "gearshape") }
            Button {
              activeSection = .scenes
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
      .animation(.spring(response: 0.3, dampingFraction: 0.5), value: sync.isOptionHeld)
      .animation(.spring(response: 0.3, dampingFraction: 0.5), value: sync.isReordering)
      .frame(height: 20)
      if !sceneStore.scenes.isEmpty, !sync.isOptionHeld {
        SceneChipsRow {
          ForEach(sceneStore.scenes) { scene in
            SceneChip(scene: scene)
          }
        }
        .padding(.top, 6)
      }
    }
  }
}
