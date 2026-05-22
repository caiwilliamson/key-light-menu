//
//  BreadcrumbHeader.swift
//  KeyLightMenu
//

import SwiftUI

/// A breadcrumb navigation header row.
/// Each crumb with an `action` is rendered as a tappable ancestor (tertiary).
/// The final crumb with no `action` is the current page (secondary, non-interactive).
struct BreadcrumbHeader: View {
  struct Crumb {
    var title: String
    var action: (() -> Void)?
  }

  let homeAction: () -> Void
  let crumbs: [Crumb]
  private let trailing: AnyView

  init(
    homeAction: @escaping () -> Void,
    crumbs: [Crumb],
    @ViewBuilder trailing: () -> some View = { EmptyView() }
  ) {
    self.homeAction = homeAction
    self.crumbs = crumbs
    self.trailing = AnyView(trailing())
  }

  var body: some View {
    HStack(spacing: 0) {
      Button(action: homeAction) {
        Text("Home")
          .font(.headline)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)

      ForEach(crumbs.indices, id: \.self) { i in
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 5)

        let crumb = crumbs[i]
        if let action = crumb.action {
          Button(action: action) {
            Text(crumb.title)
              .font(.headline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .buttonStyle(.plain)
        } else {
          Text(crumb.title)
            .font(.headline)
            .foregroundStyle(.primary)
            .fixedSize()
        }
      }

      Spacer()
      trailing
        .padding(.leading, 8)
    }
    .frame(height: 20)
  }
}
