//
//  RowAnimation.swift
//  KeyLightMenu
//

import SwiftUI

extension Animation {
  /// Spring used for all row expand/collapse animations.
  static let rowSpring = Animation.spring(response: 0.1, dampingFraction: 1.0)
}

extension AnyTransition {
  /// Content fades in after the row spring settles; disappears instantly on collapse.
  static let rowContent = AnyTransition.asymmetric(
    insertion: .opacity.animation(.easeIn(duration: 0.1).delay(0.1)),
    removal: .identity
  )
}
