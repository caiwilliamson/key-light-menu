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
  var syncKind: SyncSliderKind? = nil
  var onEditingChanged: ((Bool) -> Void)?

  @Environment(SyncCoordinator.self) private var sync

  private static let thumbSize: CGFloat = 16
  private static let trackHeight: CGFloat = 8
  private var fraction: Double {
    (value - range.lowerBound) / (range.upperBound - range.lowerBound)
  }

  /// True when sync is active, something is hovered, but it's a different kind than this slider.
  private var isKindDimmed: Bool {
    syncKind != nil && sync.syncHoveredKind != nil && sync.syncHoveredKind != syncKind
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
              .strokeBorder(Color(.tertiaryLabelColor), lineWidth: 0.5)
          )

        ZStack {
          Circle()
            .fill(gradient.color(at: fraction))
          Circle()
            .strokeBorder(.white, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
        .frame(width: Self.thumbSize, height: Self.thumbSize)
        .offset(x: max(0, min(trackWidth, fraction * trackWidth)))
      }
      .compositingGroup()
      .opacity(isKindDimmed ? 0.3 : 1.0)
      .animation(sync.isOptionHeld ? .spring(duration: 0.1) : nil, value: isKindDimmed)
      .contentShape(Rectangle())
      .onHover { hovering in
        if syncKind != nil { sync.syncHoveredKind = hovering ? syncKind : nil }
      }
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
    var color: Color {
      Color(red: r, green: g, blue: b)
    }
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
      red: a.r + (b.r - a.r) * t,
      green: a.g + (b.g - a.g) * t,
      blue: a.b + (b.b - a.b) * t
    )
  }

  static let brightness = TrackGradient(stops: [
    Stop(r: 0.45, g: 0.45, b: 0.45),
    Stop(r: 0.97, g: 0.97, b: 0.97),
  ])
  /// 143 mireds ≈ 7000K (cool/blue) → 344 mireds ≈ 2900K (warm/amber)
  static let temperature = TrackGradient(stops: [
    Stop(r: 0.6, g: 0.78, b: 1.0),
    Stop(r: 1.0, g: 0.7, b: 0.3),
  ])

  /// Brightness gradient from near-black to the colour at the given temperature (in mireds).
  static func brightness(for temperature: Int) -> TrackGradient {
    let fraction = max(0, min(1, (Double(temperature) - 143) / (344 - 143)))
    let s = Self.temperature.stops
    let scaled = fraction * Double(s.count - 1)
    let low = Int(scaled), high = min(low + 1, s.count - 1)
    let t = scaled - Double(low)
    let r = s[low].r + (s[high].r - s[low].r) * t
    let g = s[low].g + (s[high].g - s[low].g) * t
    let b = s[low].b + (s[high].b - s[low].b) * t
    return TrackGradient(stops: [Stop(r: r * 0.40, g: g * 0.40, b: b * 0.40), Stop(r: r, g: g, b: b)])
  }
}
