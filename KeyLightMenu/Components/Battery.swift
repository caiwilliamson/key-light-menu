//
//  Battery.swift
//  KeyLightMenu
//

import SwiftUI

/// Filled-bar battery indicator with a charging bolt overlay.
/// - `level`: 0.0 (empty) to 1.0 (full)
/// - `isCharging`: shows a bolt and colours the fill green
struct Battery: View {
  let level: Float
  let isCharging: Bool

  private var fillColor: Color {
    if isCharging { return .green }
    if level <= 0.2 { return .red }
    return .primary
  }

  var body: some View {
    GeometryReader { gp in
      let w = min(gp.size.width, gp.size.height * 2.15)
      ZStack(alignment: .leading) {
        barBody(w: w)
      }
      .frame(width: w, height: w / 2.15, alignment: .center)
    }
    .aspectRatio(2.15, contentMode: .fit)
  }

  private func barBody(w: CGFloat) -> some View {
    ZStack(alignment: .leading) {
      Image(systemName: "battery.0")
        .font(Font.custom("SFUIDisplay-Light", size: 200 * (w / 294)))
        .foregroundColor(.secondary)
      RoundedRectangle(cornerRadius: w * 0.040, style: .continuous)
        .frame(width: w * 0.688 * CGFloat(level), height: w * 0.276)
        .foregroundColor(fillColor)
        .offset(x: w * 0.18)
    }
    .mask(
      ZStack {
        Color.white
        Image(systemName: "battery.100")
          .font(Font.custom("SFUIDisplay-Light", size: 200 * (w / 294)))
          .foregroundColor(.black)
      }
      .compositingGroup()
      .colorInvert()
      .luminanceToAlpha()
    )
    .modifier(BoltOverlay(enabled: isCharging, width: w))
  }
}

private struct BoltOverlay: ViewModifier {
  let enabled: Bool
  let width: CGFloat

  func body(content: Content) -> some View {
    if enabled {
      ZStack(alignment: .leading) {
        content.mask(
          ZStack {
            Color.white
            Image(systemName: "battery.100.bolt")
              .font(Font.custom("SFUIDisplay-Light", size: 200 * (width / 294)))
              .foregroundColor(.black)
          }
          .compositingGroup()
          .colorInvert()
          .luminanceToAlpha()
        )
        Image(systemName: "bolt.fill")
          .foregroundColor(.primary)
          .font(Font.custom("SFUIDisplay-Light", size: 200 * (width / 294)))
          .scaleEffect(0.6)
          .offset(x: 0.2 * width)
      }
    } else {
      content
    }
  }
}
