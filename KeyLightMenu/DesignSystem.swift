//
//  DesignSystem.swift
//  KeyLightMenu
//

import SwiftUI

// MARK: - PanelSection

/// Wraps rows in a consistent vertical stack with horizontal inset.
/// Does not add vertical padding — SectionDivider owns spacing between sections.
struct PanelSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - SectionDivider

/// An inset divider between sections. Vertical spacing comes from PanelSection's padding.
struct SectionDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 12)
    }
}
