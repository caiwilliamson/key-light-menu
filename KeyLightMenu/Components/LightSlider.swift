//
//  LightSlider.swift
//  KeyLightMenu
//

import SwiftUI

/// A slider that fires immediately on first move, then throttles to ~100ms during drag.
/// Pass `nil` for `onCommit` to render a read-only preview slider.
struct LightSlider: View {
  let icon: String
  let externalValue: Double
  let range: ClosedRange<Double>
  let label: (Double) -> String
  let onCommit: ((Double) -> Void)?

  @State private var value: Double
  @State private var lastSent: Date = .distantPast
  @State private var pendingTask: Task<Void, Never>?
  @State private var isDragging = false
  private static let throttleInterval: TimeInterval = 0.2
  private static let settleInterval: TimeInterval = 0.5

  init(
    icon: String,
    value: Double,
    range: ClosedRange<Double>,
    label: @escaping (Double) -> String,
    onCommit: ((Double) -> Void)? = nil
  ) {
    self.icon = icon
    externalValue = value
    self.range = range
    self.label = label
    self.onCommit = onCommit
    _value = State(initialValue: value)
  }

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .frame(width: 20)
        .foregroundStyle(.secondary)

      if let onCommit {
        Slider(value: $value, in: range) { editing in
          isDragging = editing
          if !editing {
            pendingTask?.cancel()
            lastSent = Date()
            onCommit(value)
          }
        }
      } else {
        Slider(value: .constant(externalValue), in: range)
          .allowsHitTesting(false)
          .tint(.gray)
          .controlSize(.small)
      }

      Text(label(value))
        .frame(width: 40, alignment: .trailing)
        .monospacedDigit()
    }
    .onChange(of: value) { _, new in
      guard let onCommit else { return }
      pendingTask?.cancel()
      let elapsed = Date().timeIntervalSince(lastSent)
      if elapsed >= Self.throttleInterval {
        lastSent = Date()
        onCommit(new)
      } else {
        let delay = Self.throttleInterval - elapsed
        pendingTask = Task {
          try? await Task.sleep(for: .seconds(delay))
          guard !Task.isCancelled else { return }
          lastSent = Date()
          onCommit(new)
        }
      }
    }
    .onChange(of: externalValue) { _, new in
      if !isDragging, Date().timeIntervalSince(lastSent) > Self.settleInterval {
        value = new
      }
    }
  }
}
