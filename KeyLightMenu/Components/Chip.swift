//
//  Chip.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

struct Chip: View {
  @Environment(\.colorScheme) private var colorScheme
  let label: String
  var isActive: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isActive ? Color.accentColor : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08), in: Capsule())
        .foregroundStyle(isActive ? Color.white : Color.secondary)
        .font(.callout)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Scene Chip

struct SceneChip: View {
  @Environment(KeyLightService.self) private var service
  @Environment(\.colorScheme) private var colorScheme
  let scene: LightScene

  private enum Reachability { case all, some, none }

  private var reachability: Reachability {
    guard !scene.lights.isEmpty else { return .none }
    let reachableCount = scene.lights.filter { sl in
      service.lights.first { $0.accessoryInfo?.serialNumber == sl.serialNumber }?.isReachable == true
    }.count
    if reachableCount == scene.lights.count { return .all }
    if reachableCount == 0 { return .none }
    return .some
  }

  private var isActive: Bool {
    guard reachability != .none else { return false }
    return scene.lights.allSatisfy { sl in
      guard let light = service.lights.first(where: { $0.accessoryInfo?.serialNumber == sl.serialNumber }),
            light.isReachable
      else { return true } // unreachable lights don't disqualify
      return light.state?.brightness == sl.brightness && light.state?.temperature == sl.temperature
    }
  }

  var body: some View {
    let status = reachability
    let isDisabled = status == .none
    let active = isActive

    Button {
      for sl in scene.lights {
        guard
          let i = service.lights.firstIndex(where: { $0.accessoryInfo?.serialNumber == sl.serialNumber }),
          service.lights[i].isReachable
        else { continue }
        Task { await service.applyPreset(brightness: sl.brightness, temperature: sl.temperature, at: i) }
      }
    } label: {
      HStack(spacing: 4) {
        Text(scene.name)
        switch status {
        case .some:
          Image(systemName: "exclamationmark.circle")
        case .none:
          Image(systemName: "nosign")
        case .all:
          EmptyView()
        }
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(
        active ? Color.accentColor.opacity(status == .some ? 0.5 : 1) : Color.primary.opacity(isDisabled ? 0.04 : (colorScheme == .dark ? 0.15 : 0.08)),
        in: Capsule()
      )
      .foregroundStyle(active ? Color.white : (isDisabled ? Color.secondary.opacity(0.4) : Color.secondary))
      .font(.callout)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .tooltip(
      status == .none ? "No lights in this scene are connected." :
      status == .some ? "Some lights in this scene are not connected. \nOnly connected lights will be applied." : nil
    )
  }
}

struct ChipRow<Content: View>: View {
  var rowHeight: CGFloat = 13
  @ViewBuilder let content: Content

  @State private var expanded = false
  @State private var flowHeight: CGFloat = 0

  var body: some View {
    let isMultiRow = flowHeight > rowHeight + 8
    HStack(alignment: .firstTextBaseline) {
      HFlow(itemSpacing: 4, rowSpacing: 4) {
        content
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { flowHeight = $0 }
      .frame(maxWidth: .infinity, maxHeight: isMultiRow && !expanded ? rowHeight : nil, alignment: .topLeading)
      .clipped()
      if isMultiRow {
        Button { expanded.toggle() } label: {
          Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
  }
}
