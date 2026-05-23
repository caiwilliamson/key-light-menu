//
//  Chip.swift
//  KeyLightMenu
//

import Flow
import SwiftUI

// MARK: - Shared Label Style

private struct ChipLabelStyle: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  var isActive: Bool = false
  var activeOpacity: Double = 1
  var hPadding: CGFloat = 6
  var vPadding: CGFloat = 3

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, hPadding)
      .padding(.vertical, vPadding)
      .background(
        isActive
          ? Color.accentColor.opacity(activeOpacity)
          : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08),
        in: Capsule()
      )
      .foregroundStyle(isActive ? Color.white : Color.secondary)
      .font(.callout)
      .contentShape(Capsule())
  }
}

// MARK: - Chip

struct PresetChip: View {
  let label: String
  var isActive: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .modifier(ChipLabelStyle(isActive: isActive))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Scene Chip

struct SceneChip: View {
  @Environment(KeyLightService.self) private var service
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
      else { return true }
      return light.state?.brightness == sl.brightness && light.state?.temperature == sl.temperature
    }
  }

  var body: some View {
    let status = reachability
    let isDisabled = status == .none

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
        case .some: Image(systemName: "exclamationmark.circle")
        case .none: Image(systemName: "nosign")
        case .all: EmptyView()
        }
      }
      .modifier(ChipLabelStyle(
        isActive: isActive,
        activeOpacity: status == .some ? 0.5 : 1,
        hPadding: 9,
        vPadding: 5
      ))
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .tooltip(
      status == .none ? "No lights in this scene are connected." :
      status == .some ? "Some lights in this scene are not connected.\nOnly connected lights will be applied." : nil
    )
  }
}

struct ChipRow<Content: View>: View {
  private let rowHeight: CGFloat
  @ViewBuilder let content: Content

  fileprivate init(rowHeight: CGFloat, @ViewBuilder content: () -> Content) {
    self.rowHeight = rowHeight
    self.content = content()
  }

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

struct PresetChipsRow<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View { ChipRow(rowHeight: 21) { content } }
}

struct SceneChipsRow<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View { ChipRow(rowHeight: 25) { content } }
}
