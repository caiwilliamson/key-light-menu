//
//  Tooltip.swift
//  KeyLightMenu
//

import SwiftUI

// MARK: - Preference Keys

private struct TooltipAnchorKey: PreferenceKey {
  static var defaultValue: (text: String, anchor: Anchor<CGRect>)? = nil
  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue() ?? value
  }
}

private struct TooltipLabelSizeKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

/// Propagates whether any tooltip trigger is currently hovered.
private struct TooltipActiveKey: PreferenceKey {
  static var defaultValue: Bool = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

// MARK: - Trigger modifier

private struct TooltipModifier: ViewModifier {
  let text: String
  @State private var isHovered = false

  func body(content: Content) -> some View {
    content
      .onHover { isHovered = $0 }
      .anchorPreference(key: TooltipAnchorKey.self, value: .bounds) { anchor in
        isHovered ? (text: text, anchor: anchor) : nil
      }
      .preference(key: TooltipActiveKey.self, value: isHovered)
  }
}

// MARK: - Container modifier

private struct TooltipContainerModifier: ViewModifier {
  @State private var labelSize: CGSize = CGSize(width: 80, height: 20)
  /// Whether the tooltip label is currently shown. Controlled explicitly so we
  /// can apply the initial-appearance delay only when coming from hidden, and
  /// debounce the hide so moving between adjacent buttons doesn't cause a flash.
  @State private var isVisible = false
  @State private var pendingTask: Task<Void, Never>?
  private let edgePadding: CGFloat = 8
  private let yGap: CGFloat = 6

  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(TooltipAnchorKey.self) { value in
        GeometryReader { geo in
          if let value, isVisible {
            let rect = geo[value.anchor]
            let halfW = labelSize.width / 2
            let x = max(halfW + edgePadding, min(geo.size.width - halfW - edgePadding, rect.midX))
            let y = rect.maxY + yGap + labelSize.height / 2

            Text(value.text)
              .font(.callout)
              .padding(.horizontal, 6)
              .padding(.vertical, 3)
              .fixedSize()
              .background(
                GeometryReader { labelGeo in
                  Color.clear
                    .preference(key: TooltipLabelSizeKey.self, value: labelGeo.size)
                }
              )
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
              .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
              .position(x: x, y: y)
              .allowsHitTesting(false)
              .transition(.opacity)
          }
        }
      }
      .onPreferenceChange(TooltipActiveKey.self) { active in
        pendingTask?.cancel()
        if active {
          guard !isVisible else { return } // already showing — just let the anchor update
          // First appearance: wait 400 ms before showing
          pendingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled {
              withAnimation(.easeIn(duration: 0.1)) { isVisible = true }
            }
          }
        } else {
          // Debounce the hide so cursor transitions between adjacent buttons
          // don't produce a visible gap
          pendingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            if !Task.isCancelled { isVisible = false }
          }
        }
      }
      .onPreferenceChange(TooltipLabelSizeKey.self) { labelSize = $0 }
  }
}

// MARK: - View extensions

extension View {
  func tooltip(_ text: String) -> some View {
    modifier(TooltipModifier(text: text))
  }

  @ViewBuilder
  func tooltip(_ text: String?) -> some View {
    if let text {
      modifier(TooltipModifier(text: text))
    } else {
      self
    }
  }

  func tooltipContainer() -> some View {
    modifier(TooltipContainerModifier())
  }
}
