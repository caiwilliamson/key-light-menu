//
//  PresetChip.swift
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

struct ChipRow<Content: View>: View {
  @ViewBuilder let content: Content

  @State private var expanded = false
  @State private var flowHeight: CGFloat = 0
  private let singleRowHeight: CGFloat = 22

  var body: some View {
    let isMultiRow = flowHeight > singleRowHeight + 8
    HStack(alignment: .firstTextBaseline) {
      HFlow(itemSpacing: 4, rowSpacing: 4) {
        content
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { flowHeight = $0 }
      .frame(maxWidth: .infinity, maxHeight: isMultiRow && !expanded ? singleRowHeight : nil, alignment: .topLeading)
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
