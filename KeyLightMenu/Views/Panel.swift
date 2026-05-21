//
//  Panel.swift
//  KeyLightMenu
//

enum Panel {
  case info, presets, settings, remove

  var title: String {
    switch self {
    case .info: return "Info"
    case .presets: return "Presets"
    case .settings: return "Settings"
    case .remove: return "Remove"
    }
  }
}
