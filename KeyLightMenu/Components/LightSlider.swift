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
  let gradient: TrackGradient
  let onDragStart: (() -> Void)?
  let onDragChange: ((Double) -> Void)?
  let onCommit: ((Double) -> Void)?

  @State private var value: Double
  @State private var lastSent: Date = .distantPast
  @State private var lastDragEnd: Date = .distantPast
  @State private var pendingTask: Task<Void, Never>?
  @State private var isDragging = false
  private static let throttleInterval: TimeInterval = 0.2
  private static let settleInterval: TimeInterval = 0.5

  init(
    icon: String,
    value: Double,
    range: ClosedRange<Double>,
    label: @escaping (Double) -> String,
    gradient: TrackGradient,
    onDragStart: (() -> Void)? = nil,
    onDragChange: ((Double) -> Void)? = nil,
    onCommit: ((Double) -> Void)? = nil
  ) {
    self.icon = icon
    externalValue = value
    self.range = range
    self.label = label
    self.gradient = gradient
    self.onDragStart = onDragStart
    self.onDragChange = onDragChange
    self.onCommit = onCommit
    _value = State(initialValue: value)
  }

  var body: some View {
    Group {
      if let onCommit {
        SliderRow(icon: icon, value: $value, range: range, label: label, gradient: gradient) { editing in
          if editing && !isDragging { onDragStart?() }
          isDragging = editing
          if !editing {
            onDragChange?(value)
            pendingTask?.cancel()
            lastSent = Date()
            lastDragEnd = Date()
            onCommit(value)
          }
        }
      } else {
        SliderRow(icon: icon, value: .constant(externalValue), range: range, label: label, gradient: gradient, isActive: false)
          .allowsHitTesting(false)
      }
    }
    .onChange(of: value) { _, new in
      guard let onCommit else { return }
      if isDragging { onDragChange?(new) }
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
      if !isDragging, Date().timeIntervalSince(lastDragEnd) > Self.settleInterval {
        value = new
      }
    }
  }
}
