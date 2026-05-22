//
//  Panel.swift
//  KeyLightMenu
//

enum Panel {
  case info, presets, settings, remove

  var title: String {
    switch self {
    case .info: "Info"
    case .presets: "Presets"
    case .settings: "Settings"
    case .remove: "Remove"
    }
  }
}
