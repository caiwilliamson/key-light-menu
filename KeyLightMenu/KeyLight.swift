//
//  KeyLight.swift
//  KeyLightMenu
//

import Foundation

struct KeyLight: Identifiable {
    var id = UUID()
    var discoveredName: String
    var host: String
    var port: Int
    var state: LightState?
    var accessoryInfo: AccessoryInfo?
    var settings: LightSettings?
    var isReachable: Bool = true

    /// Prefers displayName, then productName, then the Bonjour-discovered name.
    var name: String {
        guard let info = accessoryInfo else { return discoveredName }
        return info.displayName.isEmpty ? discoveredName : info.displayName
    }

    func url(_ path: String) -> URL? {
        URL(string: "http://\(host):\(port)/elgato/\(path)")
    }
}
