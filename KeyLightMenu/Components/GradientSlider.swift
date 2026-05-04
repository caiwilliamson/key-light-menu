//
//  GradientSlider.swift
//  KeyLightMenu
//

import SwiftUI

/// A slider that renders a gradient track with a ring thumb.
struct GradientSlider: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let gradient: TrackGradient
  var isActive: Bool = true
  var onEditingChanged: ((Bool) -> Void)? = nil

  private static let thumbSize: CGFloat = 20
  private static let trackHeight: CGFloat = 9
  private var fraction: Double {
    (value - range.lowerBound) / (range.upperBound - range.lowerBound)
  }

  var body: some View {
    GeometryReader { geo in
      let trackWidth = geo.size.width - Self.thumbSize
      ZStack(alignment: .leading) {
        gradient.linearGradient
          .frame(height: Self.trackHeight)
          .clipShape(RoundedRectangle(cornerRadius: Self.trackHeight / 2))
          .overlay(
            RoundedRectangle(cornerRadius: Self.trackHeight / 2)
              .strokeBorder(.tertiary, lineWidth: 0.5)
          )
          .opacity(isActive ? 1 : 0.5)

        ZStack {
          Circle()
            .fill(gradient.color(at: fraction))
          Circle()
            .strokeBorder(.white, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
        .frame(width: Self.thumbSize, height: Self.thumbSize)
        .offset(x: max(0, min(trackWidth, fraction * trackWidth)))
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            let newFraction = max(0, min(1, (drag.location.x - Self.thumbSize / 2) / max(1, trackWidth)))
            let newValue = range.lowerBound + newFraction * (range.upperBound - range.lowerBound)
            value = newValue
            onEditingChanged?(true)
          }
          .onEnded { _ in
            onEditingChanged?(false)
          }
      )
    }
    .frame(height: Self.thumbSize)
  }
}

// MARK: - TrackGradient

/// Bundles a LinearGradient with interpolatable RGB stops so the thumb can
/// reflect the exact track colour at its current position.
struct TrackGradient {
  struct Stop {
    let r, g, b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
  }

  let stops: [Stop]

  var linearGradient: LinearGradient {
    LinearGradient(colors: stops.map(\.color), startPoint: .leading, endPoint: .trailing)
  }

  func color(at fraction: Double) -> Color {
    guard stops.count > 1 else { return stops.first?.color ?? .clear }
    let clamped = max(0, min(1, fraction))
    let scaled = clamped * Double(stops.count - 1)
    let low = Int(scaled)
    let high = min(low + 1, stops.count - 1)
    let t = scaled - Double(low)
    let a = stops[low], b = stops[high]
    return Color(
      red:   a.r + (b.r - a.r) * t,
      green: a.g + (b.g - a.g) * t,
      blue:  a.b + (b.b - a.b) * t
    )
  }

  static let brightness = TrackGradient(stops: [
    Stop(r: 0.45, g: 0.45, b: 0.45),
    Stop(r: 0.97, g: 0.97, b: 0.97)
  ])
  /// 143 mireds ≈ 7000K (cool/blue) → 344 mireds ≈ 2900K (warm/amber)
  static let temperature = TrackGradient(stops: [
    Stop(r: 0.6,  g: 0.78, b: 1.0),
    Stop(r: 1.0,  g: 0.7,  b: 0.3)
  ])
}
